# R/download_data.R - Functions for downloading validated model data releases

#' Download model data from the configured public release
#'
#' Downloads model posterior draws from the release configured in
#' `inst/extdata/data_urls.json`. Downloads are accepted only when their byte
#' size and SHA-256 checksum match the configured release manifest.
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
#' cache_dir <- file.path(tempdir(), "leafwax_download_example")
#' ok <- download_model_data(
#'   "baseline",
#'   version = "latest",
#'   cache_dir = cache_dir,
#'   verify = TRUE,
#'   verbose = FALSE
#' )
#' \dontshow{unlink(cache_dir, recursive = TRUE, force = TRUE)}
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

  # Get download URLs and, by default, the immutable release manifest.
  urls <- get_data_url(model_name, version, data_type)

  if (length(urls) == 0) {
    stop("No download URLs found for model: ", model_name)
  }

  manifest <- NULL
  if (isTRUE(verify)) {
    manifest <- get_data_manifest(cache_dir = cache_dir)
    if (is.null(manifest)) {
      stop("Checksum verification was requested, but the data manifest is unavailable.",
           call. = FALSE)
    }
    configured_version <- as.character(get_url_config()$version)
    if (!identical(as.character(manifest$version), configured_version)) {
      stop(
        "Cached data manifest version ", manifest$version,
        " does not match package configuration ", configured_version, ".",
        call. = FALSE
      )
    }
  }

  # Download each file
  success <- TRUE
  for (i in seq_along(urls)) {
    url <- urls[[i]]$url
    filename <- urls[[i]]$filename
    local_path <- file.path(cache_dir, filename)

    # Verify an existing cached file before trusting it.
    if (file.exists(local_path) && !overwrite) {
      if (isTRUE(verify)) {
        verification_error <- tryCatch({
          .verify_downloaded_file(local_path, basename(filename), manifest)
          NULL
        }, error = identity)
        if (!is.null(verification_error)) {
          unlink(local_path)
          stop(
            "Cached file failed integrity verification and was removed: ",
            filename, ". ", conditionMessage(verification_error),
            call. = FALSE
          )
        }
      }
      if (verbose) {
        message(if (isTRUE(verify)) "Verified cached file: " else "Using cached file: ",
                filename)
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

    # Download to a temporary file in the destination directory. The cached
    # path is replaced only after verification succeeds.
    temp_path <- tempfile(pattern = paste0(basename(filename), "."),
                          tmpdir = local_dir)
    on.exit(unlink(temp_path), add = TRUE)
    success <- download_with_progress(
      url = url,
      destfile = temp_path,
      verbose = verbose
    )

    if (!success) {
      warning("Failed to download: ", filename)
      success <- FALSE
      break
    }

    if (isTRUE(verify)) {
      verification_error <- tryCatch({
        .verify_downloaded_file(temp_path, basename(filename), manifest)
        NULL
      }, error = identity)
      if (!is.null(verification_error)) {
        unlink(temp_path)
        stop(
          "Downloaded file failed integrity verification and was removed: ",
          filename, ". ", conditionMessage(verification_error),
          call. = FALSE
        )
      }
      if (verbose) message("Verified SHA-256: ", filename)
    }

    if (!file.copy(temp_path, local_path, overwrite = TRUE)) {
      unlink(temp_path)
      stop("Could not move verified download into the cache: ", filename,
           call. = FALSE)
    }
    unlink(temp_path)
  }

  if (success && verbose) {
    message("Successfully downloaded all files for model: ", model_name)
  }

  return(invisible(success))
}

.verify_downloaded_file <- function(path, filename, manifest) {
  entry <- manifest$files[[filename]]
  if (is.null(entry) || is.null(entry$sha256) || is.null(entry$size_bytes)) {
    stop("Manifest has no complete entry for ", filename, ".", call. = FALSE)
  }
  expected_sha <- tolower(as.character(entry$sha256))
  if (!grepl("^[0-9a-f]{64}$", expected_sha)) {
    stop("Manifest SHA-256 is invalid for ", filename, ".", call. = FALSE)
  }
  actual_size <- unname(file.info(path)$size)
  if (!identical(as.numeric(actual_size), as.numeric(entry$size_bytes))) {
    stop(
      "File size mismatch for ", filename, ": expected ", entry$size_bytes,
      " bytes, received ", actual_size, ".",
      call. = FALSE
    )
  }
  actual_sha <- digest::digest(file = path, algo = "sha256")
  if (!identical(actual_sha, expected_sha)) {
    stop("SHA-256 mismatch for ", filename, ".", call. = FALSE)
  }
  invisible(TRUE)
}

#' Get data download URLs
#'
#' Constructs download URLs for the configured model-data release.
#'
#' @param model_name Character string specifying the model name
#' @param version Version tag (e.g., "v1.0.0" or "latest")
#' @param data_type Type of data (only "posteriors" is currently supported)
#'
#' @return List of download URLs and filenames
#' @export
#' @examples
#' \dontrun{
#' urls <- get_data_url("baseline_sp", "latest")
#' }
get_data_url <- function(model_name, version = "latest",
                        data_type = c("posteriors")) {

  data_type <- match.arg(data_type)

  # Load URL configuration
  url_config <- get_url_config()
  if (!isTRUE(url_config$release_ready)) {
    stop(
      "Public posterior download wiring is disabled in this development build ",
      "until the coordinated chordal data release passes final validation.",
      call. = FALSE
    )
  }

  valid_versions <- c("latest", as.character(url_config$release_tag))
  if (!version %in% valid_versions) {
    stop(
      "This package supports posterior data release ", url_config$release_tag,
      "; requested version was ", version, ".",
      call. = FALSE
    )
  }
  if (!model_name %in% names(url_config$models)) {
    stop("Unknown calibration model: ", model_name, call. = FALSE)
  }

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

  if (!file.exists(config_file)) {
    stop("Package data URL configuration is missing; refusing an unverified fallback URL.",
         call. = FALSE)
  }
  config <- jsonlite::fromJSON(config_file)

  return(config)
}

#' Get data manifest
#'
#' Loads or downloads the data manifest with file checksums. Returns `NULL`
#' with a warning when no current manifest is available. Download callers that
#' request verification fail closed in that case.
#'
#' @param cache_dir Cache directory containing `manifest.json`.
#' @return Parsed manifest list, or `NULL` if no manifest is
#'   available locally and the download failed.
#' @keywords internal
get_data_manifest <- function(cache_dir = NULL) {

  if (is.null(cache_dir)) cache_dir <- get_cache_dir()
  if (!dir.exists(cache_dir)) {
    dir.create(cache_dir, recursive = TRUE, showWarnings = FALSE)
  }
  manifest_file <- file.path(cache_dir, "manifest.json")
  url_config <- get_url_config()

  cached <- NULL
  if (file.exists(manifest_file)) {
    cached <- tryCatch(
      jsonlite::fromJSON(manifest_file),
      error = function(e) NULL
    )
  }
  cached_is_current <- !is.null(cached) &&
    identical(as.character(cached$version), as.character(url_config$version)) &&
    difftime(Sys.time(), file.info(manifest_file)$mtime, units = "days") <= 1

  if (!cached_is_current) {
    if (!isTRUE(url_config$release_ready)) {
      warning(
        "Public data manifest is unavailable while release wiring is disabled.",
        call. = FALSE
      )
      return(NULL)
    }

    download_err <- NULL
    temp_manifest <- tempfile(pattern = "leafwax-manifest-", tmpdir = cache_dir)
    on.exit(unlink(temp_manifest), add = TRUE)
    tryCatch({
      utils::download.file(
        url_config$manifest_url,
        temp_manifest,
        mode = "wb",
        quiet = TRUE
      )
    }, error = function(e) {
      download_err <<- conditionMessage(e)
    })

    if (!is.null(download_err)) {
      warning("Could not fetch data manifest: ", download_err,
              call. = FALSE)
      return(NULL)
    }
    downloaded <- tryCatch(
      jsonlite::fromJSON(temp_manifest),
      error = function(e) NULL
    )
    if (is.null(downloaded) ||
        !identical(as.character(downloaded$version),
                   as.character(url_config$version))) {
      warning("Downloaded data manifest is invalid or has the wrong version.",
              call. = FALSE)
      return(NULL)
    }
    if (!file.copy(temp_manifest, manifest_file, overwrite = TRUE)) {
      warning("Could not store the downloaded data manifest.", call. = FALSE)
      return(NULL)
    }
    cached <- downloaded
  }

  if (!file.exists(manifest_file)) {
    warning("Data manifest not found and could not be downloaded.",
            call. = FALSE)
    return(NULL)
  }

  cached
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
#' \donttest{
#' local({
#'   old <- options(leafwax.cache_dir = file.path(tempdir(), "leafwax_cache"))
#'   on.exit({
#'     unlink(getOption("leafwax.cache_dir"), recursive = TRUE, force = TRUE)
#'     options(old)
#'   })
#'
#'   post_dir <- file.path(getOption("leafwax.cache_dir"), "posteriors")
#'   dir.create(post_dir, recursive = TRUE, showWarnings = FALSE)
#'   file.create(file.path(post_dir, "baseline_sp_posterior.rds"))
#'
#'   # Clear cache for a specific model without prompting
#'   suppressMessages(clear_download_cache("baseline_sp", confirm = FALSE))
#' })
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
