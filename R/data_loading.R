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
#' \dontrun{
#' cache_dir <- get_cache_dir()
#' list.files(cache_dir)
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
#' \dontrun{
#' exists <- check_data_cache("baseline_sp")
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
#' \dontrun{
#' # List all cached models
#' models <- list_cached_models()
#'
#' # List models with full data
#' models_full <- list_cached_models(data_type = "full")
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

#' Clear model data cache
#'
#' Removes cached model data files to free up disk space.
#'
#' @param model_name Model to clear (NULL for all)
#' @param data_type Type of data to clear (NULL for all)
#' @param confirm Logical, whether to ask for confirmation
#' @return Logical indicating success
#' @export
#' @examples
#' \dontrun{
#' # Clear cache for specific model
#' clear_data_cache("baseline_sp")
#'
#' # Clear all full datasets
#' clear_data_cache(data_type = "full")
#' }
clear_data_cache <- function(model_name = NULL,
                            data_type = NULL,
                            confirm = TRUE) {

  cache_dir <- get_cache_dir(create = FALSE)

  if (!dir.exists(cache_dir)) {
    message("No cache directory found")
    return(TRUE)
  }

  # Get list of files to remove
  files_to_remove <- character(0)

  if (is.null(model_name)) {
    # Clear all models
    if (is.null(data_type)) {
      # Clear everything
      files_to_remove <- list.files(cache_dir, recursive = TRUE, full.names = TRUE)
    } else {
      # Clear specific data type for all models
      models <- list_cached_models(verbose = FALSE)
      for (model in models) {
        files <- get_cache_files(model, data_type, cache_dir)
        files_to_remove <- c(files_to_remove, files)
      }
    }
  } else {
    # Clear specific model
    files_to_remove <- get_cache_files(model_name, data_type, cache_dir)
  }

  if (length(files_to_remove) == 0) {
    message("No files to remove")
    return(TRUE)
  }

  # Calculate size
  total_size <- sum(file.info(files_to_remove)$size, na.rm = TRUE)
  size_mb <- round(total_size / 1024^2, 1)

  cat("Files to remove:", length(files_to_remove), "\n")
  cat("Total size:", size_mb, "MB\n")

  if (confirm && interactive()) {
    response <- readline("Proceed with deletion? (y/n): ")
    if (tolower(response) != "y") {
      message("Cancelled")
      return(FALSE)
    }
  }

  # Remove files
  success <- TRUE
  for (file in files_to_remove) {
    if (file.exists(file)) {
      tryCatch({
        file.remove(file)
        cat("Removed:", basename(file), "\n")
      }, error = function(e) {
        warning("Failed to remove ", file, ": ", e$message)
        success <- FALSE
      })
    }
  }

  # Clean up empty directories
  subdirs <- list.dirs(cache_dir, recursive = TRUE, full.names = TRUE)
  for (dir in rev(subdirs)) {
    if (length(list.files(dir)) == 0 && dir != cache_dir) {
      unlink(dir, recursive = FALSE)
    }
  }

  return(success)
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
#' \dontrun{
#' # Get total cache size
#' cache_info <- get_cache_info()
#'
#' # Get size by model and type
#' cache_info <- get_cache_info(by_model = TRUE, by_type = TRUE)
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

  # Add model name
  file_info$model <- gsub("_(metadata|2000draws|complete|grid)\\.rds$", "",
                          file_info$name)

  # Add data type
  file_info$type <- ifelse(grepl("metadata", file_info$name), "metadata",
                           ifelse(grepl("2000draws", file_info$name), "standard",
                                 ifelse(grepl("complete", file_info$name), "full",
                                       ifelse(grepl("grid", file_info$name), "spatial",
                                             "other"))))

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

#' Setup leafwax data management
#'
#' Interactive setup wizard for configuring leafwax data management options.
#'
#' @param reset Logical, whether to reset to defaults
#' @export
#' @examples
#' \dontrun{
#' # Run interactive setup
#' setup_leafwax_data()
#' }
setup_leafwax_data <- function(reset = FALSE) {

  if (reset) {
    options(leafwax.cache_dir = NULL)
    options(leafwax.data_url = NULL)
    options(leafwax.auto_download = NULL)
    message("leafwax data options reset to defaults")
    return(invisible())
  }

  if (!interactive()) {
    stop("This function must be run interactively")
  }

  cat("=== leafwax Data Management Setup ===\n\n")

  # Cache directory
  current_cache <- getOption("leafwax.cache_dir", get_data_path(FALSE))
  cat("Current cache directory:", current_cache, "\n")
  response <- readline("Enter new cache directory (or press Enter to keep current): ")

  if (nzchar(response)) {
    options(leafwax.cache_dir = response)
    cat("Cache directory set to:", response, "\n")
  }

  # Auto-download
  current_auto <- getOption("leafwax.auto_download", TRUE)
  cat("\nCurrent auto-download setting:", current_auto, "\n")
  response <- readline("Enable automatic downloads? (y/n, Enter to keep current): ")

  if (nzchar(response)) {
    options(leafwax.auto_download = tolower(response) == "y")
    cat("Auto-download set to:", tolower(response) == "y", "\n")
  }

  # Data URL
  current_url <- getOption("leafwax.data_url",
                          "https://github.com/leafwax-models/data/releases/download/v1.0.0/")
  cat("\nCurrent data URL:", current_url, "\n")
  response <- readline("Enter new data URL (or press Enter to keep current): ")

  if (nzchar(response)) {
    options(leafwax.data_url = response)
    cat("Data URL set to:", response, "\n")
  }

  cat("\n=== Setup Complete ===\n")
  cat("Settings are stored for this R session only.\n")
  cat("To make permanent, add the following to your .Rprofile:\n\n")

  cat("options(leafwax.cache_dir = \"", getOption("leafwax.cache_dir"), "\")\n", sep = "")
  cat("options(leafwax.auto_download = ", getOption("leafwax.auto_download"), ")\n", sep = "")
  cat("options(leafwax.data_url = \"", getOption("leafwax.data_url"), "\")\n", sep = "")

  invisible()
}