# R/api_functions.R - Main user-facing API functions

#' Predict precipitation d2H from leaf wax d2H
#'
#' Main user-facing function for inverting leaf wax hydrogen isotopes to
#' precipitation isotopes. Automatically selects appropriate model based on
#' available data and returns results in a tidy format.
#'
#' @param data Data frame containing measurements, or NULL to use individual vectors
#' @param d2h_wax Numeric vector of leaf wax d2H values (per mil)
#' @param longitude Numeric vector of longitudes (decimal degrees)
#' @param latitude Numeric vector of latitudes (decimal degrees)
#' @param d2h_wax_err Numeric vector of measurement uncertainties (optional)
#' @param elevation Numeric vector of elevations in meters (optional)
#' @param c4_fraction Numeric vector of C4 vegetation fraction 0-1 (optional)
#' @param pft_tree Numeric vector of tree PFT fraction (optional)
#' @param pft_shrub Numeric vector of shrub PFT fraction (optional)
#' @param pft_grass Numeric vector of grass PFT fraction (optional)
#' @param model Character string specifying model, or "auto" for automatic selection
#' @param n_draws Integer number of posterior draws (NULL for all)
#' @param use_lookup Logical whether to use lookup tables for spatial models
#' @param credible_level Numeric credible interval level (default 0.9)
#' @param return_draws Logical whether to return full posterior draws
#' @param progress Logical whether to show progress bar for batch processing
#' @param verbose Logical whether to print status messages
#'
#' @return A data frame with predictions (or list if return_draws = TRUE):
#' \describe{
#'   \item{d2h_precip_mean}{Mean predicted precipitation d2H}
#'   \item{d2h_precip_median}{Median predicted precipitation d2H}
#'   \item{d2h_precip_sd}{Standard deviation of predictions}
#'   \item{d2h_precip_lower}{Lower credible interval bound}
#'   \item{d2h_precip_upper}{Upper credible interval bound}
#'   \item{model_used}{Name of model used for prediction}
#' }
#'
#' @export
#' @examples
#' \dontrun{
#' # Using data frame input
#' data(example_data)
#' results <- predict_d2h_precip(example_data)
#'
#' # Using individual vectors
#' results <- predict_d2h_precip(
#'   d2h_wax = c(-150, -140, -130),
#'   longitude = c(-120, -110, -100),
#'   latitude = c(40, 35, 30),
#'   elevation = c(1000, 1500, 500)
#' )
#'
#' # Specify model explicitly
#' results <- predict_d2h_precip(
#'   example_data,
#'   model = "b0b1_elev_sp"
#' )
#'
#' # Get full posterior draws
#' results <- predict_d2h_precip(
#'   example_data,
#'   return_draws = TRUE
#' )
#' }
predict_d2h_precip <- function(data = NULL,
                              d2h_wax = NULL,
                              longitude = NULL,
                              latitude = NULL,
                              d2h_wax_err = NULL,
                              elevation = NULL,
                              c4_fraction = NULL,
                              pft_tree = NULL,
                              pft_shrub = NULL,
                              pft_grass = NULL,
                              model = "auto",
                              n_draws = NULL,
                              use_lookup = TRUE,
                              credible_level = 0.9,
                              return_draws = FALSE,
                              progress = TRUE,
                              verbose = TRUE) {

  # Extract variables from data frame if provided
  if (!is.null(data)) {
    if (is.null(d2h_wax) && "d2h_wax" %in% names(data)) {
      d2h_wax <- data$d2h_wax
    }
    if (is.null(longitude) && "longitude" %in% names(data)) {
      longitude <- data$longitude
    }
    if (is.null(latitude) && "latitude" %in% names(data)) {
      latitude <- data$latitude
    }
    if (is.null(d2h_wax_err)) {
      if ("d2h_wax_err" %in% names(data)) {
        d2h_wax_err <- data$d2h_wax_err
      } else if ("d2h_wax_sd" %in% names(data)) {
        d2h_wax_err <- data$d2h_wax_sd
      }
    }
    if (is.null(elevation) && "elevation" %in% names(data)) {
      elevation <- data$elevation
    }
    if (is.null(c4_fraction) && "c4_fraction" %in% names(data)) {
      c4_fraction <- data$c4_fraction
    }
    if (is.null(pft_tree) && "pft_tree" %in% names(data)) {
      pft_tree <- data$pft_tree
    }
    if (is.null(pft_shrub) && "pft_shrub" %in% names(data)) {
      pft_shrub <- data$pft_shrub
    }
    if (is.null(pft_grass) && "pft_grass" %in% names(data)) {
      pft_grass <- data$pft_grass
    }
  }

  # Validate required inputs
  if (is.null(d2h_wax)) {
    stop("d2h_wax values are required")
  }
  if (is.null(longitude) || is.null(latitude)) {
    stop("longitude and latitude are required")
  }

  n_obs <- length(d2h_wax)
  if (length(longitude) != n_obs || length(latitude) != n_obs) {
    stop("d2h_wax, longitude, and latitude must have the same length")
  }

  # Auto-select model if requested
  if (model == "auto") {
    model <- select_best_model(
      has_elevation = !is.null(elevation),
      has_c4 = !is.null(c4_fraction),
      has_pft = !is.null(pft_tree) && !is.null(pft_shrub) && !is.null(pft_grass),
      prefer_spatial = TRUE,
      verbose = verbose
    )
  }

  if (verbose) {
    cat("Using model:", model, "\n")
    if (n_obs > 10) {
      cat("Processing", n_obs, "locations...\n")
    }
  }

  # Use lookup tables for spatial models if available and requested
  lookup_table <- NULL
  if (use_lookup && grepl("_sp", model)) {
    if (verbose) cat("Checking for cached lookup table...\n")
    lookup_result <- use_lookup_if_available(
      model_name = model,
      longitude = longitude,
      latitude = latitude,
      method = "bilinear"
    )

    if (!is.null(lookup_result)) {
      lookup_table <- lookup_result$lookup_table
      if (verbose) cat("Using pre-computed lookup table\n")
    } else if (verbose) {
      cat("No lookup table found, will compute spatial effects directly\n")
    }
  }

  # Show progress bar for large datasets
  if (progress && n_obs > 10) {
    pb <- txtProgressBar(min = 0, max = n_obs, style = 3)
  } else {
    pb <- NULL
  }

  # Call the core inversion function
  tryCatch({
    results <- invert_d2h(
      d2h_wax = d2h_wax,
      d2h_wax_err = d2h_wax_err,
      longitude = longitude,
      latitude = latitude,
      elevation = elevation,
      c4_percent = c4_fraction * 100,  # Convert to percentage if needed
      pft_tree = pft_tree,
      pft_shrub = pft_shrub,
      pft_grass = pft_grass,
      model_name = model,
      n_draws = n_draws,
      return_full = return_draws,
      credible_level = credible_level,
      verbose = FALSE  # We handle verbosity here
    )

    if (!is.null(pb)) {
      setTxtProgressBar(pb, n_obs)
      close(pb)
    }

    # Add model information to results
    if (!return_draws) {
      results$model_used <- model
    } else {
      results$model_info$model_used <- model
    }

    if (verbose) {
      cat("Predictions complete\n")
    }

    return(results)

  }, error = function(e) {
    if (!is.null(pb)) close(pb)

    # Provide helpful error message
    if (grepl("not found|not available", e$message)) {
      message("\nModel data not available. To download:")
      message("  download_model_data('", model, "', 'standard')")
      message("\nOr enable auto-download:")
      message("  options(leafwax.auto_download = TRUE)")
    }

    stop(e)
  })
}

#' Select best model based on available data
#'
#' Automatically selects the most appropriate model based on which
#' covariates are available in the data.
#'
#' @param has_elevation Logical, whether elevation data is available
#' @param has_c4 Logical, whether C4 vegetation data is available
#' @param has_pft Logical, whether PFT data is available
#' @param prefer_spatial Logical, whether to prefer spatial models
#' @param verbose Logical, whether to print selection reasoning
#' @return Character string with selected model name
#' @export
select_best_model <- function(has_elevation = FALSE,
                            has_c4 = FALSE,
                            has_pft = FALSE,
                            prefer_spatial = TRUE,
                            verbose = FALSE) {

  # Build model name based on available covariates
  components <- c("b0b1")

  if (has_elevation) {
    components <- c(components, "elev")
  }
  if (has_c4) {
    components <- c(components, "c4")
  }
  if (has_pft) {
    components <- c(components, "pft")
  }
  if (prefer_spatial) {
    components <- c(components, "sp")
  }

  model_name <- paste(components, collapse = "_")

  # Check if this model exists
  data(model_metadata, envir = environment())
  if (model_name %in% names(model_metadata)) {
    if (verbose) {
      cat("Selected model:", model_name, "\n")
      cat("Reason: Best match for available covariates\n")
    }
    return(model_name)
  }

  # Fall back to simpler models
  fallback_models <- c(
    "b0b1_elev_c4_pft_sp",  # Full spatial model
    "b0b1_elev_sp",         # Elevation + spatial
    "b0b1_sp",              # Basic spatial
    "b0b1_elev",            # Elevation only
    "b0b1"                  # Base model
  )

  for (fallback in fallback_models) {
    if (fallback %in% names(model_metadata)) {
      # Check if we have the required data for this model
      model_info <- model_metadata[[fallback]]

      if (model_info$has_elevation && !has_elevation) next
      if (model_info$has_c4 && !has_c4) next
      if (model_info$has_pft && !has_pft) next

      if (verbose) {
        cat("Selected model:", fallback, "\n")
        cat("Reason: Best available fallback\n")
      }
      return(fallback)
    }
  }

  # Default to base model
  if (verbose) {
    cat("Selected model: b0b1\n")
    cat("Reason: Default base model\n")
  }
  return("b0b1")
}

#' List available models with details
#'
#' Returns information about all models available in the leafwax package,
#' including their requirements and whether data is downloaded.
#'
#' @param check_data Logical, whether to check if model data is available
#' @param verbose Logical, whether to print formatted output
#' @return Data frame with model information
#' @export
#' @examples
#' # List all models
#' models <- list_models()
#'
#' # Check which models have data available
#' models <- list_models(check_data = TRUE)
#'
#' # Silent mode (no printing)
#' models <- list_models(verbose = FALSE)
list_models <- function(check_data = TRUE, verbose = TRUE) {

  # Load model metadata
  data(model_metadata, envir = environment())

  # Create summary data frame
  model_df <- data.frame(
    model = names(model_metadata),
    stringsAsFactors = FALSE
  )

  # Extract model properties
  for (i in seq_along(model_metadata)) {
    m <- model_metadata[[i]]
    model_df$description[i] <- m$description
    model_df$has_elevation[i] <- m$has_elevation
    model_df$has_c4[i] <- m$has_c4
    model_df$has_pft[i] <- m$has_pft
    model_df$has_spatial[i] <- m$has_gp
    model_df$n_parameters[i] <- m$n_parameters

    # Create requirements string
    reqs <- c()
    if (m$has_elevation) reqs <- c(reqs, "elevation")
    if (m$has_c4) reqs <- c(reqs, "C4 fraction")
    if (m$has_pft) reqs <- c(reqs, "PFT fractions")
    model_df$requires[i] <- if (length(reqs) > 0) {
      paste(reqs, collapse = ", ")
    } else {
      "none"
    }
  }

  # Check data availability if requested
  if (check_data) {
    model_df$data_package <- FALSE
    model_df$data_cached <- FALSE
    model_df$data_status <- "Not available"

    for (i in seq_len(nrow(model_df))) {
      model_name <- model_df$model[i]

      # Check package data
      if (model_name %in% list_available_models()) {
        model_df$data_package[i] <- TRUE
        model_df$data_status[i] <- "In package"
      }

      # Check cached data
      if (check_data_cache(model_name, "standard", verbose = FALSE)) {
        model_df$data_cached[i] <- TRUE
        model_df$data_status[i] <- "Downloaded"
      }
    }
  }

  if (verbose) {
    cat("=== Available Models in leafwax ===\n\n")

    # Group by complexity
    simple_models <- model_df[!model_df$has_spatial, ]
    spatial_models <- model_df[model_df$has_spatial, ]

    if (nrow(simple_models) > 0) {
      cat("Non-spatial models:\n")
      for (i in seq_len(nrow(simple_models))) {
        m <- simple_models[i, ]
        cat(sprintf("  %-25s %s\n", m$model, m$description))
        if (m$requires != "none") {
          cat(sprintf("  %-25s Requires: %s\n", "", m$requires))
        }
        if (check_data) {
          cat(sprintf("  %-25s Status: %s\n", "", m$data_status))
        }
        cat("\n")
      }
    }

    if (nrow(spatial_models) > 0) {
      cat("\nSpatial models (with Gaussian process):\n")
      for (i in seq_len(nrow(spatial_models))) {
        m <- spatial_models[i, ]
        cat(sprintf("  %-25s %s\n", m$model, m$description))
        if (m$requires != "none") {
          cat(sprintf("  %-25s Requires: %s\n", "", m$requires))
        }
        if (check_data) {
          cat(sprintf("  %-25s Status: %s\n", "", m$data_status))
        }
        cat("\n")
      }
    }

    cat("Total models:", nrow(model_df), "\n")

    if (check_data) {
      n_available <- sum(model_df$data_status != "Not available")
      cat("Models with data:", n_available, "of", nrow(model_df), "\n")

      if (n_available < nrow(model_df)) {
        cat("\nTo download model data:\n")
        cat("  download_model_data(model_name, 'standard')\n")
      }
    }
  }

  return(invisible(model_df))
}

#' Validate input data for inversion
#'
#' Checks that input data meets requirements for the specified model
#' and returns cleaned, validated data.
#'
#' @param d2h_wax Leaf wax d2H values
#' @param longitude Longitude values
#' @param latitude Latitude values
#' @param d2h_wax_err Measurement uncertainties
#' @param elevation Elevation values
#' @param c4_fraction C4 vegetation fraction
#' @param pft_tree Tree PFT fraction
#' @param pft_shrub Shrub PFT fraction
#' @param pft_grass Grass PFT fraction
#' @param model_name Name of model to use
#' @return List of validated inputs
#' @export
validate_inputs <- function(d2h_wax, longitude, latitude,
                          d2h_wax_err = NULL,
                          elevation = NULL,
                          c4_fraction = NULL,
                          pft_tree = NULL,
                          pft_shrub = NULL,
                          pft_grass = NULL,
                          model_name = "b0b1") {

  # Check required inputs
  if (is.null(d2h_wax) || length(d2h_wax) == 0) {
    stop("d2h_wax is required and cannot be empty")
  }

  n <- length(d2h_wax)

  if (is.null(longitude) || length(longitude) != n) {
    stop("longitude must have the same length as d2h_wax")
  }

  if (is.null(latitude) || length(latitude) != n) {
    stop("latitude must have the same length as d2h_wax")
  }

  # Check data types and ranges
  if (!is.numeric(d2h_wax)) {
    stop("d2h_wax must be numeric")
  }

  if (any(is.na(d2h_wax))) {
    stop("d2h_wax cannot contain NA values")
  }

  if (any(d2h_wax < -300) || any(d2h_wax > 0)) {
    warning("d2h_wax values outside typical range (-300 to 0 per mil)")
  }

  # Check coordinates
  if (!is.numeric(longitude) || !is.numeric(latitude)) {
    stop("longitude and latitude must be numeric")
  }

  if (any(longitude < -180) || any(longitude > 180)) {
    stop("longitude must be between -180 and 180")
  }

  if (any(latitude < -90) || any(latitude > 90)) {
    stop("latitude must be between -90 and 90")
  }

  # Set default uncertainty if not provided
  if (is.null(d2h_wax_err)) {
    d2h_wax_err <- rep(3, n)  # Default 3 per mil uncertainty
  } else if (length(d2h_wax_err) == 1) {
    d2h_wax_err <- rep(d2h_wax_err, n)
  } else if (length(d2h_wax_err) != n) {
    stop("d2h_wax_err must be a single value or same length as d2h_wax")
  }

  # Load model metadata to check requirements
  data(model_metadata, envir = environment())

  if (!model_name %in% names(model_metadata)) {
    stop("Unknown model: ", model_name)
  }

  model_info <- model_metadata[[model_name]]

  # Check model-specific requirements
  if (model_info$has_elevation) {
    if (is.null(elevation)) {
      stop("Model ", model_name, " requires elevation data")
    }
    if (length(elevation) != n) {
      stop("elevation must have the same length as d2h_wax")
    }
    if (!is.numeric(elevation)) {
      stop("elevation must be numeric")
    }
    if (any(elevation < -500) || any(elevation > 9000)) {
      warning("elevation values outside typical range (-500 to 9000 m)")
    }
  }

  if (model_info$has_c4) {
    if (is.null(c4_fraction)) {
      stop("Model ", model_name, " requires c4_fraction data")
    }
    if (length(c4_fraction) != n) {
      stop("c4_fraction must have the same length as d2h_wax")
    }
    if (!is.numeric(c4_fraction)) {
      stop("c4_fraction must be numeric")
    }
    if (any(c4_fraction < 0) || any(c4_fraction > 1)) {
      stop("c4_fraction must be between 0 and 1")
    }
  }

  if (model_info$has_pft) {
    if (is.null(pft_tree) || is.null(pft_shrub) || is.null(pft_grass)) {
      stop("Model ", model_name, " requires pft_tree, pft_shrub, and pft_grass")
    }

    for (pft_name in c("pft_tree", "pft_shrub", "pft_grass")) {
      pft_val <- get(pft_name)
      if (length(pft_val) != n) {
        stop(pft_name, " must have the same length as d2h_wax")
      }
      if (!is.numeric(pft_val)) {
        stop(pft_name, " must be numeric")
      }
      if (any(pft_val < 0) || any(pft_val > 1)) {
        stop(pft_name, " must be between 0 and 1")
      }
    }

    # Check that PFT fractions sum to 1
    pft_sum <- pft_tree + pft_shrub + pft_grass
    if (any(abs(pft_sum - 1) > 0.01)) {
      warning("PFT fractions do not sum to 1 at some locations")
    }
  }

  # Return validated inputs
  validated <- list(
    d2h_wax = d2h_wax,
    d2h_wax_err = d2h_wax_err,
    longitude = longitude,
    latitude = latitude,
    n_obs = n,
    model_name = model_name
  )

  if (model_info$has_elevation) validated$elevation <- elevation
  if (model_info$has_c4) validated$c4_fraction <- c4_fraction
  if (model_info$has_pft) {
    validated$pft_tree <- pft_tree
    validated$pft_shrub <- pft_shrub
    validated$pft_grass <- pft_grass
  }

  return(validated)
}