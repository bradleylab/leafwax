# R/zzz.R - Package startup configuration

# Null-coalescing operator. Built into base R from 4.4.0 onward, but
# the package depends on R >= 3.5, so we define it ourselves to keep
# behavior consistent across versions.
`%||%` <- function(x, y) if (is.null(x)) y else x

# Standardised wording for the preview-tier warning. Emitted from
# load_posteriors() when it falls back to inst/extdata/posteriors_light/,
# and again from invert_d2H() / assess_claim() / detect_change() so the
# warning is visible at the inferential call rather than only at the
# (often nested) data-loading call.
preview_tier_message <- function(model_name, n_draws, context = NULL) {
  ctx <- if (is.null(context)) "" else paste0(" (", context, ")")
  paste0(
    "leafwax preview posteriors in use", ctx, ": ",
    n_draws, " draws of '", model_name, "'. ",
    "Tail probabilities and 95% credible intervals are unstable at ",
    "this sample size; not suitable for inference. ",
    "Run download_model_data(\"", model_name, "\") for the full ",
    "posterior."
  )
}

# Emit the preview-tier warning, gated by getOption("leafwax.suppress_preview_warning").
# Tests set the option to TRUE in tests/testthat/helper-data.R; batch
# users who have already acknowledged the limitation can do the same.
warn_preview_tier <- function(model_name, n_draws, context = NULL) {
  if (isTRUE(getOption("leafwax.suppress_preview_warning"))) {
    return(invisible())
  }
  warning(preview_tier_message(model_name, n_draws, context),
          call. = FALSE)
}

.onLoad <- function(libname, pkgname) {
  # Set default options if not already set
  op <- options()

  op.leafwax <- list(
    # Default data URL for downloading model data. Points at the
    # bradleylab/leafwax-data archive, pinned to release v1.0.0.
    # Concept DOI: 10.5281/zenodo.20085465.
    leafwax.data_url = "https://raw.githubusercontent.com/bradleylab/leafwax-data/v1.0.0",

    # Default cache directory (NULL means use rappdirs default)
    leafwax.cache_dir = NULL,

    # Whether to automatically download missing data
    leafwax.auto_download = FALSE,

    # Default timeout for downloads (in seconds)
    leafwax.download_timeout = 300,

    # Whether to show progress messages
    leafwax.verbose = TRUE,

    # Default data type to load ("minimal", "standard", or "full")
    leafwax.default_data_type = "standard",

    # Suppress the warning emitted when the preview-tier (100-draw
    # fixture) posteriors are loaded. Set to TRUE in batch jobs that
    # have already acknowledged the limitation.
    leafwax.suppress_preview_warning = FALSE
  )

  # Only set options that haven't been set by user
  toset <- !(names(op.leafwax) %in% names(op))
  if (any(toset)) options(op.leafwax[toset])

  invisible()
}

.onAttach <- function(libname, pkgname) {
  # Check if this is the first time loading the package
  cache_dir <- get_cache_dir(create = FALSE)
  has_cache <- dir.exists(cache_dir) && length(list.files(cache_dir)) > 0

  if (!has_cache && interactive()) {
    packageStartupMessage(
      "Welcome to leafwax!\n",
      "This appears to be your first time using the package.\n",
      "Model data can be downloaded on demand using:\n",
      "  download_model_data(model_name, data_type)\n",
      "Or configure auto-download:\n",
      "  options(leafwax.auto_download = TRUE)\n",
      "Run setup_leafwax_data() for interactive setup."
    )
  } else if (has_cache && interactive()) {
    # Show cache status
    cache_info <- get_cache_info()
    if (cache_info$file_count > 0) {
      packageStartupMessage(
        sprintf("leafwax: %d model files cached (%.1f MB)",
                cache_info$file_count,
                cache_info$total_size_mb)
      )
    }
  }

  invisible()
}

#' Get leafwax configuration
#'
#' Returns current configuration options for the leafwax package.
#'
#' @param option Specific option to retrieve (NULL for all)
#' @return List of options or single option value
#' @export
#' @examples
#' \dontrun{
#' # Get all configuration options
#' leafwax_config()
#'
#' # Get specific option
#' leafwax_config("auto_download")
#' }
leafwax_config <- function(option = NULL) {
  all_options <- list(
    data_url = getOption("leafwax.data_url"),
    cache_dir = getOption("leafwax.cache_dir"),
    auto_download = getOption("leafwax.auto_download"),
    download_timeout = getOption("leafwax.download_timeout"),
    verbose = getOption("leafwax.verbose"),
    default_data_type = getOption("leafwax.default_data_type")
  )

  if (!is.null(option)) {
    if (option %in% names(all_options)) {
      return(all_options[[option]])
    } else {
      stop("Unknown option: ", option,
           "\nAvailable options: ", paste(names(all_options), collapse = ", "))
    }
  }

  return(all_options)
}

#' Set leafwax configuration
#'
#' Sets configuration options for the leafwax package.
#'
#' @param ... Named arguments for options to set
#' @param persist Logical, whether to show code to make changes permanent
#' @return Invisible NULL
#' @export
#' @examples
#' \dontrun{
#' # Enable auto-download
#' leafwax_set_config(auto_download = TRUE)
#'
#' # Set multiple options
#' leafwax_set_config(
#'   auto_download = TRUE,
#'   cache_dir = "~/my_leafwax_cache",
#'   verbose = FALSE
#' )
#' }
leafwax_set_config <- function(..., persist = TRUE) {
  args <- list(...)

  valid_options <- c("data_url", "cache_dir", "auto_download",
                    "download_timeout", "verbose", "default_data_type")

  # Check for invalid options
  invalid <- setdiff(names(args), valid_options)
  if (length(invalid) > 0) {
    stop("Invalid options: ", paste(invalid, collapse = ", "),
         "\nValid options: ", paste(valid_options, collapse = ", "))
  }

  # Set options
  for (opt in names(args)) {
    options(structure(list(args[[opt]]), names = paste0("leafwax.", opt)))
  }

  if (persist && interactive()) {
    cat("\nOptions set for current session.\n")
    cat("To make permanent, add the following to your .Rprofile:\n\n")

    for (opt in names(args)) {
      if (is.character(args[[opt]])) {
        cat(sprintf("options(leafwax.%s = \"%s\")\n", opt, args[[opt]]))
      } else {
        cat(sprintf("options(leafwax.%s = %s)\n", opt, args[[opt]]))
      }
    }
  }

  invisible()
}