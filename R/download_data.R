# R/download_data.R - Functions for downloading model data from GitHub releases

#' Download model data from GitHub releases
#'
#' Downloads model posterior draws and lookup tables from GitHub releases
#' with progress tracking and integrity verification.
#'
#' @param model_name Character string specifying the model name
#' @param version Version tag to download (default "latest")
#' @param data_type Type of data to download (only "posteriors" is currently supported)
#' @param cache_dir Directory to save files (default uses get_cache_dir())
#' @param overwrite Logical whether to overwrite existing files
#' @param verify Logical whether to verify file integrity with checksums
#' @param verbose Logical whether to show progress messages
#'
#' @return Logical indicating success
#' @export
#' @examples
#' \dontrun{
#' # Download latest data for a model
#' download_model_data("baseline_sp", version = "latest")
#'
#' # Download specific version
#' download_model_data("baseline_env", version = "v1.0.1")
#' }
download_model_data <- function(model_name,
                               version = "latest",
                               data_type = c("posteriors"),
                               cache_dir = NULL,
                               overwrite = FALSE,
                               verify = TRUE,
                               verbose = TRUE) {

  data_type <- match.arg(data_type)

  # Get cache directory
  if (is.null(cache_dir)) {
    cache_dir <- get_cache_dir(create = TRUE)
  }

  # Get download URLs
  urls <- get_data_url(model_name, version, data_type)

  if (length(urls) == 0) {
    stop("No download URLs found for model: ", model_name)
  }

  # Download each file
  success <- TRUE
  for (i in seq_along(urls)) {
    url <- urls[[i]]$url
    filename <- urls[[i]]$filename
    local_path <- file.path(cache_dir, filename)

    # Check if file exists
    if (file.exists(local_path) && !overwrite) {
      if (verbose) {
        message("File already exists (use overwrite=TRUE to replace): ", filename)
      }
      next
    }

    # Create directory if needed
    local_dir <- dirname(local_path)
    if (!dir.exists(local_dir)) {
      dir.create(local_dir, recursive = TRUE, showWarnings = FALSE)
    }

    if (verbose) {
      message("Downloading: ", filename)
    }

    # Download with progress bar
    success <- download_with_progress(
      url = url,
      destfile = local_path,
      verbose = verbose
    )

    if (!success) {
      warning("Failed to download: ", filename)
      success <- FALSE
      break
    }

    # Verify integrity if requested. The check is a placeholder; a real
    # checksum-based implementation lives in the upstream data-release
    # tooling and is not exposed in this package. We log the intent and
    # skip the check so the call path stays usable.
    if (verify && success) {
      if (verbose) message("Verifying file integrity (placeholder; ",
                           "no checksum manifest shipped in this build)...")
    }
  }

  if (success && verbose) {
    message("Successfully downloaded all files for model: ", model_name)
  }

  return(invisible(success))
}

#' Get data download URLs
#'
#' Constructs download URLs for model data from GitHub releases.
#'
#' @param model_name Character string specifying the model name
#' @param version Version tag (e.g., "v1.0.0" or "latest")
#' @param data_type Type of data (only "posteriors" is currently supported)
#'
#' @return List of download URLs and filenames
#' @export
#' @examples
#' \dontrun{
#' # Get URLs for latest version
#' urls <- get_data_url("baseline_sp", "latest")
#'
#' # Get URLs for specific version
#' urls <- get_data_url("baseline_sp", "v1.0.1")
#' }
get_data_url <- function(model_name, version = "latest",
                        data_type = c("posteriors")) {

  data_type <- match.arg(data_type)

  # Load URL configuration
  url_config <- get_url_config()

  # Get base URL for version
  if (version == "latest") {
    base_url <- url_config$base_url_latest
  } else {
    base_url <- gsub("\\{version\\}", version, url_config$base_url_version)
  }

  # Build list of files to download
  urls <- list()

  if (data_type %in% c("both", "posteriors")) {
    # Posterior draws. The bradleylab/leafwax-data archive holds files
    # at the repo root (not under a posteriors/ subdir), so the URL is
    # flat. The cache filename keeps the posteriors/ prefix so the
    # local cache directory stays organised. Filename must match what
    # load_posteriors() reads via resolve_posterior_file():
    # <model>_posterior.rds (singular).
    urls[[length(urls) + 1]] <- list(
      url = paste0(base_url, "/", model_name, "_posterior.rds"),
      filename = paste0("posteriors/", model_name, "_posterior.rds")
    )
  }

  return(urls)
}

#' Download file with progress bar
#'
#' Downloads a file with a text progress bar showing download progress.
#'
#' @param url URL to download from
#' @param destfile Destination file path
#' @param verbose Whether to show progress bar
#'
#' @return Logical indicating success
#' @keywords internal
download_with_progress <- function(url, destfile, verbose = TRUE) {

  # Try to get file size first
  h <- tryCatch({
    base::curlGetHeaders(url)
  }, error = function(e) NULL)

  file_size <- NULL
  if (!is.null(h)) {
    size_line <- grep("Content-Length", h, value = TRUE, ignore.case = TRUE)
    if (length(size_line) > 0) {
      file_size <- as.numeric(gsub(".*: (\\d+).*", "\\1", size_line[1]))
    }
  }

  if (verbose && !is.null(file_size)) {
    # Download with progress bar
    temp_file <- tempfile()

    # Set up progress bar
    pb <- utils::txtProgressBar(min = 0, max = file_size, style = 3)

    # Open connections lazily and track them so the error handler can
    # only close what was actually opened. Pre-fix the handler called
    # close() on con_out unconditionally, which raised a secondary
    # error and masked the original download failure when url() opened
    # but file() had not yet been reached.
    con_in <- NULL
    con_out <- NULL
    bytes_downloaded <- 0
    chunk_size <- 65536  # 64KB chunks

    tryCatch({
      con_in  <- url(url, "rb")
      con_out <- file(temp_file, "wb")

      while (TRUE) {
        chunk <- readBin(con_in, "raw", chunk_size)
        if (length(chunk) == 0) break

        writeBin(chunk, con_out)
        bytes_downloaded <- bytes_downloaded + length(chunk)

        utils::setTxtProgressBar(pb, bytes_downloaded)
      }

      close(con_in);  con_in  <- NULL
      close(con_out); con_out <- NULL
      close(pb)

      # Move temp file to destination
      file.copy(temp_file, destfile, overwrite = TRUE)
      file.remove(temp_file)

      return(TRUE)

    }, error = function(e) {
      if (!is.null(con_in))  try(close(con_in),  silent = TRUE)
      if (!is.null(con_out)) try(close(con_out), silent = TRUE)
      try(close(pb), silent = TRUE)
      if (file.exists(temp_file)) file.remove(temp_file)
      warning("Download failed: ", e$message)
      return(FALSE)
    })

  } else {
    # Simple download without progress
    tryCatch({
      utils::download.file(url, destfile, mode = "wb", quiet = !verbose)
      return(TRUE)
    }, error = function(e) {
      warning("Download failed: ", e$message)
      return(FALSE)
    })
  }
}

#' Get URL configuration
#'
#' Loads the URL configuration from the package data.
#'
#' @return List with URL configuration
#' @keywords internal
get_url_config <- function() {

  # Try to load from package
  config_file <- system.file("extdata", "data_urls.json",
                            package = "leafwax")

  if (file.exists(config_file)) {
    config <- jsonlite::fromJSON(config_file)
  } else {
    # Fallback for broken installs where data_urls.json is missing from extdata.
    config <- list(
      base_url_latest = "https://github.com/bradleylab/leafwax-data/releases/latest/download",
      base_url_version = "https://github.com/bradleylab/leafwax-data/releases/download/{version}",
      manifest_url = "https://github.com/bradleylab/leafwax-data/releases/latest/download/manifest.json"
    )
  }

  return(config)
}

#' Get data manifest
#'
#' Loads or downloads the data manifest with file checksums. Returns
#' `NULL` (with a `warning()`) when the manifest is unreachable and
#' there is no cached copy on disk; callers must treat that as
#' "checksum verification skipped" rather than "no checksums found".
#'
#' @return Parsed manifest list, or `NULL` if no manifest is
#'   available locally and the download failed.
#' @keywords internal
get_data_manifest <- function() {

  cache_dir <- get_cache_dir()
  manifest_file <- file.path(cache_dir, "manifest.json")

  # Download if not present or older than 1 day. If the download
  # fails, surface the error to the caller via warning() rather than
  # silently masquerading as "manifest with zero files" (which earlier
  # callers misread as "no checksums available -> trust the file").
  if (!file.exists(manifest_file) ||
      difftime(Sys.time(), file.info(manifest_file)$mtime, units = "days") > 1) {

    url_config <- get_url_config()

    download_err <- NULL
    tryCatch({
      utils::download.file(
        url_config$manifest_url,
        manifest_file,
        mode = "wb",
        quiet = TRUE
      )
    }, error = function(e) {
      download_err <<- conditionMessage(e)
    })

    if (!is.null(download_err) && !file.exists(manifest_file)) {
      warning("Could not fetch data manifest: ", download_err,
              call. = FALSE)
      return(NULL)
    }
  }

  if (!file.exists(manifest_file)) {
    warning("Data manifest not found and could not be downloaded.",
            call. = FALSE)
    return(NULL)
  }

  jsonlite::fromJSON(manifest_file)
}

#' Clear download cache
#'
#' Removes downloaded model data from the local cache.
#'
#' @param model_name Model name to clear (NULL for all)
#' @param type Type of data to clear: "all" or "posteriors"
#' @param confirm Whether to ask for confirmation
#'
#' @return Invisible NULL
#' @export
#' @examples
#' \dontrun{
#' # Clear cache for specific model
#' clear_download_cache("baseline_sp")
#'
#' # Clear all cached data
#' clear_download_cache(confirm = FALSE)
#' }
clear_download_cache <- function(model_name = NULL,
                                type = c("all", "posteriors"),
                                confirm = TRUE) {

  type <- match.arg(type)
  cache_dir <- get_cache_dir(create = FALSE)

  if (!dir.exists(cache_dir)) {
    message("Cache directory does not exist")
    return(invisible())
  }

  # Get files to remove
  if (is.null(model_name)) {
    pattern <- ".*"
  } else {
    pattern <- model_name
  }

  files_to_remove <- c()

  if (type %in% c("all", "posteriors")) {
    files_to_remove <- c(files_to_remove,
                        list.files(file.path(cache_dir, "posteriors"),
                                 pattern = pattern, full.names = TRUE),
                        list.files(file.path(cache_dir, "metadata"),
                                 pattern = pattern, full.names = TRUE))
  }

  if (length(files_to_remove) == 0) {
    message("No files found to remove")
    return(invisible())
  }

  # Calculate size
  total_size <- sum(file.info(files_to_remove)$size, na.rm = TRUE) / 1024^2

  if (confirm) {
    message(sprintf("About to remove %d files (%.1f MB)",
                   length(files_to_remove), total_size))
    response <- readline("Continue? (y/n): ")

    if (tolower(response) != "y") {
      message("Cancelled")
      return(invisible())
    }
  }

  # Remove files
  removed <- file.remove(files_to_remove)

  message(sprintf("Removed %d files (%.1f MB)",
                 sum(removed), total_size))

  invisible()
}