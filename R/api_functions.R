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
#' @param record_id Optional identifier for one same-site record; required for
#'   multi-row input.
#' @param model Character string specifying model, or "auto" for automatic selection
#' @param n_draws Integer number of posterior draws (NULL for all)
#' @param credible_level Numeric credible interval level (default 0.9)
#' @param return_draws Logical whether to return full posterior draws
#' @param progress Logical whether to show progress bar for batch processing
#' @param verbose Logical whether to print status messages
#' @param prior Required proper precipitation-isotope prior.
#' @param n_inverse_samples Number of joint posterior samples when
#'   `return_draws = TRUE`.
#' @param seed Explicit seed required when posterior samples are requested.
#' @param grid_size,integration_tolerance,tail_mass_tolerance Numerical
#'   integration controls passed to [invert_d2H()].
#' @param draw_stability_tolerance Saved-draw stability tolerance in per mil.
#'
#' @return A `leafwax_inverse` object. Its `summary` data frame contains the
#'   posterior median, central interval, and supporting moments for each row;
#'   diagnostics and method metadata are always returned. Joint
#'   `posterior_draws` are included only when `return_draws = TRUE` with an
#'   explicit sample count and seed.
#'
#' The interval is the posterior predictive specified in manuscript
#' Supplementary Note 8 (Section S8.1; analytical uncertainty plus the
#' model's posterior residual SD).
#'
#' @export
#' @examples
#' \dontrun{
#' local({
#'   old <- options(leafwax.suppress_preview_warning = TRUE)
#'   on.exit(options(old))
#'
#'   # Using data frame input
#'   data(example_data)
#'   prior <- d2h_prior_normal(mean = -70, sd = 30)
#'   results <- predict_d2h_precip(
#'     example_data, prior = prior, verbose = FALSE
#'   )
#'
#'   # Using individual vectors
#'   results <- predict_d2h_precip(
#'     d2h_wax = c(-150, -140, -130),
#'     longitude = rep(-90, 3),
#'     latitude = rep(38, 3),
#'     record_id = "example_record",
#'     elevation = c(1000, 1500, 500), prior = prior,
#'     verbose = FALSE
#'   )
#'
#'   # Specify model explicitly
#'   results <- predict_d2h_precip(
#'     example_data,
#'     model = "baseline_sp", prior = prior,
#'     verbose = FALSE
#'   )
#'
#'   # Get full posterior draws
#'   results <- predict_d2h_precip(
#'     example_data,
#'     prior = prior, return_draws = TRUE,
#'     n_inverse_samples = 1000, seed = 20260801,
#'     verbose = FALSE
#'   )
#' })
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
                              record_id = NULL,
                              model = "auto",
                              n_draws = NULL,
                              credible_level = 0.9,
                              return_draws = FALSE,
                              progress = TRUE,
                              verbose = TRUE,
                              prior = NULL,
                              n_inverse_samples = 0L,
                              seed = NULL,
                              grid_size = 2001L,
                              integration_tolerance = 1e-3,
                              tail_mass_tolerance = 1e-8,
                              draw_stability_tolerance = 2) {

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
    if (is.null(record_id) && "record_id" %in% names(data)) {
      record_id <- data$record_id
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
    if (!is.null(pft_tree) || !is.null(pft_shrub) || !is.null(pft_grass)) {
      stop("Automatic Bayesian inversion cannot consume PFT covariates; choose a supported model explicitly.",
           call. = FALSE)
    }
    model <- if (is.null(c4_fraction)) "baseline_sp" else "c4_only_sp"
    if (!is.null(elevation)) {
      warning("Elevation is retained in output metadata but is not a predictor in the selected Bayesian inversion.",
              call. = FALSE)
    }
  }

  if (verbose) {
    cat("Using model:", model, "\n")
    if (n_obs > 10) {
      cat("Processing", n_obs, "locations...\n")
    }
  }

  # Convert c4 from public-API fraction (0-1) to internal percent
  # (0-100). NULL must stay NULL so the model-capability check inside
  # invert_d2h() does not see a length-0 vector and warn spuriously.
  if (!is.null(c4_fraction)) {
    n_obs <- length(d2h_wax)
    if (length(c4_fraction) != n_obs) {
      stop(sprintf(
        "c4_fraction has length %d but d2h_wax has length %d; vector lengths must match.",
        length(c4_fraction), n_obs
      ))
    }
    if (any(c4_fraction < 0, na.rm = TRUE) ||
        any(c4_fraction > 1, na.rm = TRUE)) {
      stop("c4_fraction must be in [0, 1] (a fraction, not a percent). ",
           "Got values up to ", signif(max(c4_fraction, na.rm = TRUE), 3),
           ". If your inputs are on the 0-100 percent scale, divide by 100.")
    }
  }
  c4_percent_internal <- if (is.null(c4_fraction)) NULL else c4_fraction * 100

  # Call the core inversion function
  tryCatch({
    results <- invert_d2h(
      d2h_wax = d2h_wax,
      d2h_wax_err = d2h_wax_err,
      longitude = longitude,
      latitude = latitude,
      elevation = elevation,
      c4_percent = c4_percent_internal,
      pft_tree = pft_tree,
      pft_shrub = pft_shrub,
      pft_grass = pft_grass,
      record_id = record_id,
      model_name = model,
      n_draws = n_draws,
      return_full = return_draws,
      credible_level = credible_level,
      verbose = FALSE,
      prior = prior,
      n_inverse_samples = n_inverse_samples,
      seed = seed,
      grid_size = grid_size,
      integration_tolerance = integration_tolerance,
      tail_mass_tolerance = tail_mass_tolerance,
      draw_stability_tolerance = draw_stability_tolerance
    )

    results$model_info$model_used <- model

    if (verbose) {
      cat("Predictions complete\n")
    }

    return(results)

  }, error = function(e) {
    # Provide helpful error message
    if (grepl("not found|not available", e$message)) {
      message(
        "\nComplete model data are unavailable. Install the full posterior ",
        "archive in the package cache or use a validated working checkout."
      )
    }

    stop(e)
  })
}

#' Select best model based on available data
#'
#' Automatically selects the most appropriate model name from the 14
#' shipped variants given which covariates the user has available.
#' Spatial-aware models are preferred when `prefer_spatial = TRUE`.
#'
#' @param has_elevation Logical, whether elevation data is available.
#'   Accepted for compatibility; the reconstruction interface does not consume
#'   fitted elevation coefficients, so elevation alone does not change
#'   the selected model.
#' @param has_c4 Logical, whether C4 vegetation data is available
#' @param has_pft Logical, whether PFT data is available
#' @param prefer_spatial Logical, whether to prefer spatial models
#' @param verbose Logical, whether to print selection reasoning
#' @return Character string with the selected model name
#' @export
select_best_model_from_flags <- function(has_elevation = FALSE,
                                         has_c4 = FALSE,
                                         has_pft = FALSE,
                                         prefer_spatial = TRUE,
                                         verbose = FALSE) {
  available <- available_models()
  pref <- function(name) name %in% available

  # Pick the richest model that uses every fitted covariate the user has.
  # Elevation is not used for routing because the Bayesian reconstruction
  # does not consume elevation, independent of
  # whether the deposit carries beta_elev columns. Chordal deposits DO retain
  # those columns, but routing still ignores elevation by design -- do not
  # route on elevation unless the inversion is changed to consume it.
  # If prefer_spatial is FALSE, drop "_sp" suffix candidates first.
  candidates <- if (prefer_spatial) {
    if (has_pft && has_c4) {
      c("full_interact_sp", "full_sp", "baseline_veg_sp",
        "c4_only_sp", "baseline_sp")
    } else if (has_c4) {
      c("c4_only_sp", "baseline_sp")
    } else {
      c("baseline_sp")
    }
  } else {
    if (has_pft && has_c4) {
      c("full_interact", "full", "baseline_veg", "baseline")
    } else {
      c("baseline")
    }
  }
  for (cand in candidates) {
    if (pref(cand)) {
      if (verbose) {
        cat("Selected model:", cand, "\n")
        cat("Reason: best match for available covariates",
            if (prefer_spatial) "(prefer_spatial=TRUE)" else "(non-spatial)",
            "\n")
      }
      return(cand)
    }
  }

  # Default to baseline_sp if available, else baseline
  fallback <- if ("baseline_sp" %in% available) "baseline_sp" else "baseline"
  if (verbose) {
    cat("Selected model:", fallback, "\n")
    cat("Reason: default fallback (no candidate matched)\n")
  }
  return(fallback)
}

#' List available models with details
#'
#' Returns information about the calibration models available in the leafwax
#' package, including which covariates each model uses.
#'
#' @param check_data Logical, whether to check if model data is available
#' @param verbose Logical, whether to print formatted output
#' @return Data frame with model information
#' @export
#' @examples
#' \donttest{
#' # List all models
#' models <- list_models(verbose = FALSE)
#' models_head <- head(models)
#' }
list_models <- function(check_data = TRUE, verbose = TRUE) {

  # Pull metadata directly from the model routing layer (model_utils.R)
  metadata <- get_all_model_metadata()

  # Create summary data frame
  model_df <- data.frame(
    model = names(metadata),
    stringsAsFactors = FALSE
  )

  # Extract model properties
  for (i in seq_along(metadata)) {
    m <- metadata[[i]]
    model_df$description[i]  <- m$description %||% NA_character_
    model_df$has_elevation[i] <- isTRUE(m$has_elevation)
    model_df$has_precip[i]    <- isTRUE(m$has_precip)
    model_df$has_c4[i]        <- isTRUE(m$has_c4)
    model_df$has_pft[i]       <- isTRUE(m$has_vegetation %||% m$has_pft)
    model_df$has_spatial[i]   <- isTRUE(m$has_spatial %||% m$has_gp)
    model_df$size_mb[i]       <- m$size_mb %||% NA_real_

    # Create requirements string
    reqs <- c()
    if (isTRUE(m$has_elevation)) reqs <- c(reqs, "elevation")
    if (isTRUE(m$has_c4)) reqs <- c(reqs, "C4 fraction")
    if (isTRUE(m$has_vegetation %||% m$has_pft)) reqs <- c(reqs, "PFT fractions")
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
      if (model_name %in% available_models()) {
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
        cat("\nAutomatic full-posterior download is not configured in this build.\n")
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
                          model_name = "baseline") {

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

  metadata <- get_all_model_metadata()

  if (!model_name %in% names(metadata)) {
    stop("Unknown model: ", model_name)
  }

  model_info <- metadata[[model_name]]

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

  # Current metadata uses `has_vegetation`; the older `has_pft` field is kept
  # as a fallback so legacy callers passing in their own metadata still work.
  has_pft_flag <- isTRUE(model_info$has_vegetation %||% model_info$has_pft)
  if (has_pft_flag) {
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

  if (isTRUE(model_info$has_elevation)) validated$elevation <- elevation
  if (isTRUE(model_info$has_c4)) validated$c4_fraction <- c4_fraction
  # Current metadata uses has_vegetation in place of has_pft; honour both so
  # PFT vectors aren't silently dropped from the validated list when a
  # caller passes a compatible metadata object.
  if (has_pft_flag) {
    validated$pft_tree <- pft_tree
    validated$pft_shrub <- pft_shrub
    validated$pft_grass <- pft_grass
  }

  return(validated)
}
