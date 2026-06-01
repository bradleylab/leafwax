# R/data_loading.R - Lazy loading and data management for large model files

#' Get leafwax data cache directory
#'
#' Returns the path to the local cache directory for leafwax model data.
#' Uses rappdirs for platform-specific paths or a user-specified directory.
#'
#' @param create Logical, whether to create the directory if it doesn't exist
#' @return Character string with the cache directory path
#' @export
#' @examples
#' \donttest{
#' local({
#'   old <- options(leafwax.cache_dir = file.path(tempdir(), "leafwax_cache"))
#'   on.exit(options(old))
#'
#'   cache_dir <- get_cache_dir(create = FALSE)
#'   dir.exists(cache_dir)
#' })
#' }
get_cache_dir <- function(create = TRUE) {
  # Check for user-specified cache directory
  custom_dir <- getOption("leafwax.cache_dir")

  if (!is.null(custom_dir)) {
    cache_dir <- custom_dir
  } else {
    # Use rappdirs for platform-specific cache directory
    if (requireNamespace("rappdirs", quietly = TRUE)) {
      cache_dir <- file.path(rappdirs::user_cache_dir("leafwax"), "model_data")
    } else {
      # Fallback to home directory
      cache_dir <- file.path(Sys.getenv("HOME"), ".leafwax", "model_data")
    }
  }

  if (create && !dir.exists(cache_dir)) {
    dir.create(cache_dir, recursive = TRUE, showWarnings = FALSE)
  }

  return(cache_dir)
}

#' Get path to data file
#'
#' Returns the full path to a data file based on the data source.
#'
#' @param filename Name of the file
#' @param data_source Source of data: "package", "cache", or "download"
#' @return Character string with the file path
#' @export
get_data_path <- function(filename, data_source = "auto") {
  if (data_source == "package") {
    return(system.file("extdata", filename, package = "leafwax"))
  } else if (data_source == "cache") {
    return(file.path(get_cache_dir(), filename))
  } else if (data_source == "download") {
    return(file.path(getwd(), filename))
  } else {
    # Auto mode - check in order
    pkg_path <- system.file("extdata", filename, package = "leafwax")
    if (file.exists(pkg_path)) return(pkg_path)

    cache_path <- file.path(get_cache_dir(), filename)
    if (file.exists(cache_path)) return(cache_path)

    return(file.path(getwd(), filename))
  }
}

#' Check if model data exists in cache
#'
#' Checks whether the heavy posterior file for a model is present in
#' the user cache populated by [download_model_data()].
#'
#' @param model_name Character string specifying the model name.
#' @param data_type Retained for API compatibility. The v0.2 download
#'   layout ships a single posterior file per model
#'   (`posteriors/<model>_posterior.rds`) so all values check the same
#'   path; the argument is accepted but otherwise ignored.
#' @param verbose Logical, whether to print status messages.
#' @return Logical indicating whether the cached posterior file exists.
#' @export
#' @examples
#' \donttest{
#' local({
#'   old <- options(leafwax.cache_dir = file.path(tempdir(), "leafwax_cache"))
#'   on.exit(options(old))
#'
#'   exists <- check_data_cache("baseline_sp", verbose = FALSE)
#' })
#' }
check_data_cache <- function(model_name,
                             data_type = c("minimal", "standard", "full"),
                             verbose = FALSE) {

  data_type <- match.arg(data_type)
  cache_dir <- get_cache_dir(create = FALSE)

  if (!dir.exists(cache_dir)) {
    if (verbose) cat("Cache directory does not exist\n")
    return(FALSE)
  }

  posterior_file <- file.path(cache_dir, "posteriors",
                              paste0(model_name, "_posterior.rds"))
  exists <- file.exists(posterior_file)

  if (verbose) {
    status <- if (exists) "[OK]" else "[X]"
    cat("Checking cache for model", model_name, "\n")
    cat("  ", status, basename(posterior_file), "\n")
  }

  return(exists)
}

#' List available models in cache
#'
#' Lists all models that have been downloaded to the local cache.
#'
#' @param data_type Filter by data type (NULL for any)
#' @param verbose Logical, whether to print detailed information
#' @return Character vector of available model names
#' @export
#' @examples
#' \donttest{
#' local({
#'   old <- options(leafwax.cache_dir = file.path(tempdir(), "leafwax_cache"))
#'   on.exit(options(old))
#'
#'   # List all cached models
#'   models <- list_cached_models(verbose = FALSE)
#'
#'   # List models with full data
#'   models_full <- list_cached_models(data_type = "full", verbose = FALSE)
#' })
#' }
list_cached_models <- function(data_type = NULL, verbose = TRUE) {

  cache_dir <- get_cache_dir(create = FALSE)

  if (!dir.exists(cache_dir)) {
    if (verbose) cat("No cache directory found\n")
    return(character(0))
  }

  posteriors_dir <- file.path(cache_dir, "posteriors")
  if (!dir.exists(posteriors_dir)) {
    if (verbose) cat("No posteriors directory found in cache\n")
    return(character(0))
  }

  posterior_files <- list.files(posteriors_dir, pattern = "_posterior\\.rds$")
  if (length(posterior_files) == 0) {
    if (verbose) cat("No models found in cache\n")
    return(character(0))
  }

  models <- gsub("_posterior\\.rds$", "", posterior_files)

  if (verbose) {
    cat("Cached models:\n")
    for (model in models) cat("  ", model, "\n")
    cat("\nCache directory:", cache_dir, "\n")
  }

  return(models)
}

#' Get cache files for a model
#'
#' Internal helper that returns the cached file paths for a model.
#' The v0.2 download layout ships a single posterior per model at
#' `posteriors/<model>_posterior.rds`, so the returned vector has at
#' most one element. The `data_type` argument is accepted for API
#' compatibility but does not affect the result.
#'
#' @param model_name Model name.
#' @param data_type Retained for API compatibility (ignored).
#' @param cache_dir Cache directory path.
#' @return Character vector of cached file paths that exist on disk.
#' @keywords internal
get_cache_files <- function(model_name, data_type, cache_dir) {
  posterior_file <- file.path(cache_dir, "posteriors",
                              paste0(model_name, "_posterior.rds"))
  posterior_file[file.exists(posterior_file)]
}

#' Get cache size information
#'
#' Reports the disk space used by cached model data.
#'
#' @param by_model Logical, whether to break down by model
#' @param by_type Logical, whether to break down by data type
#' @return Data frame with cache size information
#' @export
#' @examples
#' \donttest{
#' local({
#'   old <- options(leafwax.cache_dir = file.path(tempdir(), "leafwax_cache"))
#'   on.exit(options(old))
#'
#'   # Get total cache size
#'   cache_info <- get_cache_info()
#'
#'   # Get size by model and type
#'   cache_info <- get_cache_info(by_model = TRUE, by_type = TRUE)
#' })
#' }
get_cache_info <- function(by_model = FALSE, by_type = FALSE) {

  cache_dir <- get_cache_dir(create = FALSE)

  if (!dir.exists(cache_dir)) {
    return(data.frame(
      total_size_mb = 0,
      file_count = 0,
      cache_dir = NA_character_
    ))
  }

  all_files <- list.files(cache_dir, recursive = TRUE, full.names = TRUE)

  if (length(all_files) == 0) {
    return(data.frame(
      total_size_mb = 0,
      file_count = 0,
      cache_dir = cache_dir
    ))
  }

  file_info <- file.info(all_files)
  file_info$path <- all_files
  file_info$name <- basename(all_files)

  # Classify cache files using the v0.2 download layout. download_data
  # writes posteriors as posteriors/<model>_posterior.rds and
  # spatial-knot fixtures as spatial_metadata/<model>_knots.rds.
  # The package's manifest lands at the cache root as manifest.json.
  file_info$model <- gsub("_(posterior|knots)\\.rds$", "", file_info$name)

  file_info$type <- ifelse(grepl("_posterior\\.rds$", file_info$name), "posterior",
                    ifelse(grepl("_knots\\.rds$",     file_info$name), "spatial",
                    ifelse(file_info$name == "manifest.json",          "manifest",
                                                                         "other")))

  # Calculate sizes in MB
  file_info$size_mb <- round(file_info$size / 1024^2, 2)

  if (!by_model && !by_type) {
    # Total summary
    return(data.frame(
      total_size_mb = round(sum(file_info$size_mb, na.rm = TRUE), 2),
      file_count = nrow(file_info),
      cache_dir = cache_dir
    ))
  }

  if (by_model && !by_type) {
    # By model
    summary <- aggregate(size_mb ~ model, file_info, sum)
    summary$file_count <- aggregate(size_mb ~ model, file_info, length)$size_mb
    return(summary[order(summary$size_mb, decreasing = TRUE), ])
  }

  if (!by_model && by_type) {
    # By type
    summary <- aggregate(size_mb ~ type, file_info, sum)
    summary$file_count <- aggregate(size_mb ~ type, file_info, length)$size_mb
    return(summary[order(summary$size_mb, decreasing = TRUE), ])
  }

  if (by_model && by_type) {
    # By model and type
    summary <- aggregate(size_mb ~ model + type, file_info, sum)
    summary$file_count <- aggregate(size_mb ~ model + type, file_info, length)$size_mb
    return(summary[order(summary$model, summary$type), ])
  }
}
