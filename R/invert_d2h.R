# R/invert_d2h.R

#' @importFrom stats rnorm median sd quantile dist
NULL

#' Load model posteriors from package data
#' @param model_name Name of the model
#' @param auto_download Logical whether to auto-download if missing
#' @return Posterior draws as a data frame
#' @export
load_model_posteriors <- function(model_name, auto_download = NULL) {

  # Check if data exists locally
  has_data <- check_model_data(model_name, verbose = FALSE)

  if (!has_data) {
    if (is.null(auto_download)) {
      auto_download <- getOption("leafwax.auto_download", FALSE)
    }

    if (!auto_download && interactive()) {
      message("Model data for '", model_name, "' not found locally.")
      message("Would you like to download it now? (~",
              get_model_size_estimate(model_name), " MB)")
      response <- readline("Download? (y/n): ")

      if (tolower(response) == "y") {
        success <- download_model_data(model_name, verbose = TRUE)
        if (!success) {
          stop("Failed to download model data")
        }
      } else {
        # Try to use lightweight package data if available
        message("Using lightweight example data (results may be less accurate)")
        return(use_example_data(model_name))
      }
    } else if (auto_download) {
      message("Downloading model data for '", model_name, "'...")
      success <- download_model_data(model_name, verbose = TRUE)
      if (!success) {
        warning("Download failed, using lightweight example data")
        return(use_example_data(model_name))
      }
    } else {
      # Use lightweight data without prompting
      return(use_example_data(model_name))
    }
  }

  # Load the model using existing function
  model <- load_posteriors(model_name)
  return(model$draws)
}

#' Check if model data exists locally
#'
#' @param model_name Name of the model
#' @param verbose Whether to print messages
#' @return Logical indicating if data exists
#' @keywords internal
check_model_data <- function(model_name, verbose = TRUE) {

  # Check package data
  pkg_file <- system.file(
    "extdata", "posterior_draws",
    paste0(model_name, ".rds"),
    package = "leafwax"
  )

  if (file.exists(pkg_file) && pkg_file != "") {
    return(TRUE)
  }

  # Check cache
  cache_dir <- get_cache_dir(create = FALSE)
  cache_file <- file.path(cache_dir, "posteriors",
                          paste0(model_name, "_posteriors.rds"))

  if (file.exists(cache_file)) {
    return(TRUE)
  }

  if (verbose) {
    message("Model data for '", model_name, "' not found")
  }

  return(FALSE)
}

#' Get estimated download size for a model
#'
#' @param model_name Name of the model
#' @return Estimated size in MB
#' @keywords internal
get_model_size_estimate <- function(model_name) {

  # Load URL configuration
  config_file <- system.file("extdata", "data_urls.json", package = "leafwax")

  if (file.exists(config_file)) {
    config <- jsonlite::fromJSON(config_file)

    if (model_name %in% names(config$models)) {
      model_info <- config$models[[model_name]]
      total_size <- sum(sapply(model_info$files, function(x) x$size_mb))
      return(round(total_size, 1))
    }
  }

  # Default estimate based on model type
  if (grepl("sp", model_name)) {
    return(35)  # Spatial models are larger
  } else {
    return(2)   # Non-spatial models
  }
}

#' Use lightweight example data
#'
#' Falls back to minimal example data when full data is not available
#'
#' @param model_name Name of the model
#' @return Minimal posterior draws
#' @keywords internal
use_example_data <- function(model_name) {

  # Try to load mini posteriors from package
  mini_file <- system.file(
    "extdata", "mini_posteriors",
    paste0(model_name, "_mini.rds"),
    package = "leafwax"
  )

  if (file.exists(mini_file) && mini_file != "") {
    return(readRDS(mini_file))
  }

  # Generate synthetic data as last resort
  message("Generating synthetic example data (for demonstration only)")

  n_draws <- 100
  synthetic <- data.frame(
    b0 = rnorm(n_draws, mean = 20, sd = 5),
    b1 = rnorm(n_draws, mean = 0.8, sd = 0.05),
    sigma = abs(rnorm(n_draws, mean = 10, sd = 2))
  )

  if (grepl("elev", model_name)) {
    synthetic$b_elev <- rnorm(n_draws, mean = -0.005, sd = 0.001)
  }

  if (grepl("c4", model_name)) {
    synthetic$b_c4 <- rnorm(n_draws, mean = -0.3, sd = 0.05)
  }

  if (grepl("pft", model_name)) {
    synthetic$b_pft_tree <- rnorm(n_draws, mean = 0.1, sd = 0.02)
    synthetic$b_pft_shrub <- rnorm(n_draws, mean = -0.05, sd = 0.02)
    synthetic$b_pft_grass <- rnorm(n_draws, mean = -0.1, sd = 0.02)
  }

  return(synthetic)
}

#' Invert leaf wax d2H to precipitation d2H
#' 
#' Uses Bayesian posterior draws to invert leaf wax hydrogen isotope values
#' to precipitation isotope values, accounting for all model components including
#' elevation effects and spatial correlations.
#' 
#' @param d2h_wax Numeric vector of leaf wax d2H values (per mil)
#' @param d2h_wax_err Numeric vector of measurement uncertainties (per mil)
#' @param longitude Numeric vector of longitudes (decimal degrees)
#' @param latitude Numeric vector of latitudes (decimal degrees)
#' @param elevation Numeric vector of elevations (meters)
#' @param c4_percent Numeric vector of C4 vegetation percentage (0-100)
#' @param pft_tree Numeric vector of tree PFT fraction (0-1)
#' @param pft_shrub Numeric vector of shrub PFT fraction (0-1)
#' @param pft_grass Numeric vector of grass PFT fraction (0-1)
#' @param model Character string specifying which model to use (default: "baseline").
#'   Available models: "baseline", "baseline_sp", "baseline_env", "baseline_env_sp",
#'   "baseline_veg", "baseline_veg_sp", "c4_only_sp", "elevation_only_sp",
#'   "elevation_c4_sp", "elevation_c4_interact_sp", "full", "full_sp",
#'   "full_interact", "full_interact_sp". Use available_models() for full list.
#' @param n_draws Integer number of posterior draws to use (NULL for all)
#' @param return_full Logical whether to return full posterior draws or just summary
#' @param credible_level Numeric credible interval level (default 0.9)
#' @param verbose Logical whether to print progress messages
#' 
#' @return If return_full is FALSE, a data frame with columns:
#'   \item{d2h_precip_mean}{Mean predicted precipitation d2H}
#'   \item{d2h_precip_median}{Median predicted precipitation d2H}
#'   \item{d2h_precip_sd}{Standard deviation of predictions}
#'   \item{d2h_precip_lower}{Lower credible interval bound}
#'   \item{d2h_precip_upper}{Upper credible interval bound}
#'   
#'   If return_full is TRUE, a list with:
#'   \item{summary}{The summary data frame described above}
#'   \item{posterior_draws}{Matrix of all posterior draws (n_draws x n_locations)}
#'   \item{model_info}{Information about the model used}
#'   
#' @export
#' 
#' @examples
#' \dontrun{
#' # Simple inversion with base model
#' results <- invert_d2h(
#'   d2h_wax = c(-150, -140, -130),
#'   d2h_wax_err = c(3, 3, 3),
#'   longitude = c(-120, -110, -100),
#'   latitude = c(40, 35, 30),
#'   elevation = c(1000, 1500, 500),
#'   model = "baseline"
#' )
#'
#' # Inversion with spatial model
#' results <- invert_d2h(
#'   d2h_wax = c(-150, -140, -130),
#'   d2h_wax_err = c(3, 3, 3),
#'   longitude = c(-120, -110, -100),
#'   latitude = c(40, 35, 30),
#'   elevation = c(1000, 1500, 500),
#'   model = "baseline_sp",
#'   return_full = TRUE
#' )
#' }
invert_d2h <- function(d2h_wax, d2h_wax_err = NULL,
                       longitude, latitude, elevation = NULL,
                       c4_percent = NULL,
                       pft_tree = NULL, pft_shrub = NULL, pft_grass = NULL,
                       model_name = "baseline", 
                       n_draws = NULL,
                       return_full = FALSE,
                       credible_level = 0.9,
                       verbose = TRUE) {
  
  # Input validation
  n_obs <- length(d2h_wax)
  if (length(longitude) != n_obs || length(latitude) != n_obs) {
    stop("All input vectors must have the same length")
  }
  
  # Set default uncertainty if not provided
  if (is.null(d2h_wax_err)) {
    d2h_wax_err <- rep(3.0, n_obs)  # Default 3 per mil uncertainty
    if (verbose) cat("Using default measurement uncertainty of 3 per mil\n")
  }
  
  # Load the model
  if (verbose) cat("Loading model:", model_name, "\n")
  model <- load_posteriors(model_name, n_draws = n_draws, verbose = verbose)
  
  # Check that requested predictors match the model
  model_meta <- model$metadata
  
  if (!is.null(elevation) && !model_meta$has_elevation) {
    warning("Elevation provided but model ", model_name, " does not include elevation effects")
    elevation <- NULL
  }
  
  if (!is.null(c4_percent) && !model_meta$has_c4) {
    warning("C4 percent provided but model ", model_name, " does not include C4 effects")
    c4_percent <- NULL
  }
  
  if (!is.null(pft_tree) && !model_meta$has_pft) {
    warning("PFT values provided but model ", model_name, " does not include PFT effects")
    pft_tree <- pft_shrub <- pft_grass <- NULL
  }
  
  # Set defaults for missing predictors
  if (is.null(elevation)) elevation <- rep(0, n_obs)
  if (is.null(c4_percent)) c4_percent <- rep(25, n_obs)  # Global average
  if (is.null(pft_tree)) pft_tree <- rep(0.33, n_obs)
  if (is.null(pft_shrub)) pft_shrub <- rep(0.33, n_obs)
  if (is.null(pft_grass)) pft_grass <- rep(0.34, n_obs)
  
  # Normalize PFT if needed
  pft_sum <- pft_tree + pft_shrub + pft_grass
  pft_tree <- pft_tree / pft_sum
  pft_shrub <- pft_shrub / pft_sum
  pft_grass <- pft_grass / pft_sum
  
  if (verbose) cat("Performing inversion for", n_obs, "locations\n")
  
  # Get draws
  draws <- model$draws
  n_iter <- nrow(draws)

  # Initialize posterior prediction matrix
  d2h_precip_post <- matrix(NA, nrow = n_iter, ncol = n_obs)

  # Initialize scaling early so the elevation and spatial blocks below can
  # reference it. Defaults are used when model$scaling is NULL.
  if (is.null(model$scaling)) {
    scaling <- list(
      d2H_mean = -200, d2H_sd = 50,
      oipc_mean = -50, oipc_sd = 50,
      c4_mean = 25,   c4_sd = 25,
      lon_mean = 0,   lon_sd = 90,
      lat_mean = 0,   lat_sd = 45,
      elev_mean = 1000, elev_sd = 1000
    )
    if (verbose) cat("  Using default scaling parameters (model lacks scaling data)\n")
  } else {
    scaling <- model$scaling
  }

  # Get base parameters
  base_params <- model$get_base_params()
  beta_0 <- base_params$beta_0
  beta_oipc <- base_params$beta_oipc
  sigma <- base_params$sigma
  
  # Get scale weights using lambda_decay
  lambda_decay <- base_params$lambda_decay
  effective_scale <- base_params$effective_scale_km
  
  # Get vegetation parameters if applicable
  beta_c4 <- rep(0, n_iter)
  beta_tree <- rep(0, n_iter)
  beta_shrub <- rep(0, n_iter)
  beta_grass <- rep(0, n_iter)
  
  if (model_meta$has_c4 || model_meta$has_pft) {
    veg_params <- model$get_vegetation_params()
    if (!is.null(veg_params$beta_c4)) beta_c4 <- veg_params$beta_c4
    if (!is.null(veg_params$beta_tree)) beta_tree <- veg_params$beta_tree
    if (!is.null(veg_params$beta_shrub)) beta_shrub <- veg_params$beta_shrub
    if (!is.null(veg_params$beta_grass)) beta_grass <- veg_params$beta_grass
  }
  
  # Get elevation parameters if applicable
  elev_effect <- matrix(0, nrow = n_iter, ncol = n_obs)
  if (model_meta$has_elevation) {
    elev_params <- model$get_elevation_params()
    if (!is.null(elev_params)) {
      beta_elev_spline <- elev_params$coefficients
      
      # Check if we have elevation knots
      if (!is.null(model$elevation) && !is.null(model$elevation$knots)) {
        elev_knots <- model$elevation$knots
        
        # Standardize elevation using same scaling as in model fitting
        elev_mean_km <- scaling$elev_mean / 1000
        elev_sd_km <- scaling$elev_sd / 1000
        elevation_std <- (elevation / 1000 - elev_mean_km) / elev_sd_km
        
        # Compute elevation effect for each location
        for (i in 1:n_obs) {
          elev_val <- elevation_std[i]
          
          # Simple linear interpolation between knots
          if (elev_val <= elev_knots[1]) {
            elev_effect[, i] <- beta_elev_spline[, 1]
          } else if (elev_val >= elev_knots[length(elev_knots)]) {
            elev_effect[, i] <- beta_elev_spline[, ncol(beta_elev_spline)]
          } else {
            # Find knot interval
            for (k in 1:(length(elev_knots) - 1)) {
              if (elev_val >= elev_knots[k] && elev_val <= elev_knots[k + 1]) {
                w <- (elev_val - elev_knots[k]) / (elev_knots[k + 1] - elev_knots[k])
                elev_effect[, i] <- (1 - w) * beta_elev_spline[, k] + w * beta_elev_spline[, k + 1]
                break
              }
            }
          }
        }
      } else {
        warning("Elevation knots not found in model metadata. Elevation effects will be ignored.")
      }
    }
  }
  
  # Get spatial effects if applicable
  spatial_effect <- matrix(0, nrow = n_iter, ncol = n_obs)
  if (model_meta$has_gp) {
    spatial_params <- model$get_spatial_params()
    
    if (!is.null(spatial_params$z_spatial) && !is.null(model$spatial$knot_locs)) {
      # We need to predict at new locations using the GP
      z_spatial <- spatial_params$z_spatial
      sigma_gp <- spatial_params$sigma_gp
      ls_gp <- spatial_params$ls_gp
      knot_locs <- model$spatial$knot_locs
      
      # Standardize coordinates using stored scaling parameters
      if (!is.null(scaling$lon_mean)) {
        lon_std <- (longitude - scaling$lon_mean) / scaling$lon_sd
        lat_std <- (latitude - scaling$lat_mean) / scaling$lat_sd
      } else {
        # Fallback to simple standardization
        warning("Coordinate scaling parameters not found. Using simple standardization.")
        lon_std <- (longitude - mean(longitude)) / sd(longitude)
        lat_std <- (latitude - mean(latitude)) / sd(latitude)
      }
      
      coords_new <- cbind(lon_std, lat_std)
      
      # Check if we have K_knots matrix
      if (!is.null(model$spatial$K_knots)) {
        K_knots <- model$spatial$K_knots
        
        # For each posterior draw
        for (iter in 1:n_iter) {
          # Current hyperparameters
          ls_current <- ls_gp[iter]
          sigma_current <- sigma_gp[iter]
          z_current <- z_spatial[iter, ]
          
          # Compute covariance between new locations and knots
          K_new_knots <- matrix(NA, n_obs, nrow(knot_locs))
          for (i in 1:n_obs) {
            for (j in 1:nrow(knot_locs)) {
              dist_sq <- sum((coords_new[i, ] - knot_locs[j, ])^2)
              K_new_knots[i, j] <- exp(-sqrt(dist_sq) / ls_current)
            }
          }
          
          # Add jitter for numerical stability
          K_knots_reg <- K_knots + diag(1e-6, nrow(K_knots))
          
          # Predictive process: spatial_effect = sigma_gp * K_new_knots * inv(K_knots) * z
          spatial_effect[iter, ] <- sigma_current * K_new_knots %*% solve(K_knots_reg, z_current)
        }
      } else {
        # If K_knots is missing, we need to reconstruct it
        warning("K_knots matrix not found. Reconstructing from knot locations...")
        
        # Pre-compute distance matrices to avoid repeated calculations
        n_knots <- nrow(knot_locs)
        knot_dists_sq <- matrix(0, n_knots, n_knots)
        for (i in 1:(n_knots-1)) {
          for (j in (i+1):n_knots) {
            d_sq <- sum((knot_locs[i, ] - knot_locs[j, ])^2)
            knot_dists_sq[i, j] <- d_sq
            knot_dists_sq[j, i] <- d_sq
          }
        }
        
        new_knot_dists_sq <- matrix(0, n_obs, n_knots)
        for (i in 1:n_obs) {
          for (j in 1:n_knots) {
            new_knot_dists_sq[i, j] <- sum((coords_new[i, ] - knot_locs[j, ])^2)
          }
        }
        
        # Progress indicator for long computations
        if (n_iter > 100 && verbose) {
          cat("  Computing spatial effects for", n_iter, "iterations...\n")
          pb <- txtProgressBar(min = 0, max = n_iter, style = 3)
        }
        
        for (iter in 1:n_iter) {
          if (n_iter > 100 && verbose && iter %% 50 == 0) {
            setTxtProgressBar(pb, iter)
          }
          
          # Current hyperparameters
          ls_current <- ls_gp[iter]
          sigma_current <- sigma_gp[iter]
          z_current <- z_spatial[iter, ]
          
          # Reconstruct K_knots using pre-computed distances
          K_knots_iter <- exp(-sqrt(knot_dists_sq) / ls_current)
          diag(K_knots_iter) <- 1.0
          
          # Compute covariance between new locations and knots
          K_new_knots <- exp(-sqrt(new_knot_dists_sq) / ls_current)
          
          # Add jitter for numerical stability
          K_knots_reg <- K_knots_iter + diag(1e-6, n_knots)
          
          # Predictive process - use solve() which is faster than matrix inverse
          spatial_effect[iter, ] <- sigma_current * K_new_knots %*% solve(K_knots_reg, z_current)
        }
        
        if (n_iter > 100 && verbose) {
          close(pb)
        }
      }
    }
  }
  
  # scaling was initialized at the top of the function (above) so the
  # elevation and spatial blocks can use it. No re-initialization here.

  # Standardize predictors using available scaling
  d2h_wax_std <- (d2h_wax - scaling$d2H_mean) / scaling$d2H_sd
  d2h_wax_err_std <- d2h_wax_err / scaling$d2H_sd

  c4_std <- (c4_percent - scaling$c4_mean) / scaling$c4_sd
  
  # Compute predictions for each location
  if (verbose) cat("Computing predictions...\n")
  
  for (iter in 1:n_iter) {
    # Build the mean prediction
    mu_std <- beta_0[iter] + 
      elev_effect[iter, ] +
      beta_c4[iter] * c4_std +
      beta_tree[iter] * pft_tree +
      beta_shrub[iter] * pft_shrub +
      beta_grass[iter] * pft_grass +
      spatial_effect[iter, ]
    
    # CRITICAL: Implement uncertainty propagation correctly
    # The measurement has uncertainty, but we don't add sigma here
    # because sigma represents unexplained variance that's already
    # accounted for through the Bayesian posterior
    for (i in 1:n_obs) {
      # Only add measurement uncertainty
      d2h_wax_with_error <- rnorm(1, d2h_wax_std[i], d2h_wax_err_std[i])
      
      # Invert to get precipitation d2H (in standardized space)
      d2h_precip_std <- (d2h_wax_with_error - mu_std[i]) / beta_oipc[iter]
      
      # Back-transform to original scale
      d2h_precip_post[iter, i] <- d2h_precip_std * scaling$oipc_sd + scaling$oipc_mean
    }
  }
  
  # Compute summaries
  alpha <- 1 - credible_level
  lower_q <- alpha / 2
  upper_q <- 1 - alpha / 2
  
  summary_df <- data.frame(
    longitude = longitude,
    latitude = latitude,
    elevation = elevation,
    d2h_wax = d2h_wax,
    d2h_wax_err = d2h_wax_err,
    d2h_precip_mean = colMeans(d2h_precip_post),
    d2h_precip_median = apply(d2h_precip_post, 2, median),
    d2h_precip_sd = apply(d2h_precip_post, 2, sd),
    d2h_precip_lower = apply(d2h_precip_post, 2, quantile, probs = lower_q),
    d2h_precip_upper = apply(d2h_precip_post, 2, quantile, probs = upper_q)
  )
  
  # Add prediction interval width
  summary_df$prediction_interval_width <- summary_df$d2h_precip_upper - summary_df$d2h_precip_lower
  
  if (verbose) {
    cat("\nInversion complete:\n")
    cat("  Mean prediction range: [", 
        round(min(summary_df$d2h_precip_mean), 1), ", ",
        round(max(summary_df$d2h_precip_mean), 1), "] per mil\n", sep = "")
    cat("  Mean uncertainty (SD):", round(mean(summary_df$d2h_precip_sd), 1), "per mil\n")
    cat("  Mean ", round(credible_level * 100), "% CI width: ", 
        round(mean(summary_df$prediction_interval_width), 1), " per mil\n", sep = "")
  }
  
  if (return_full) {
    return(list(
      summary = summary_df,
      posterior_draws = d2h_precip_post,
      model_info = list(
        model_name = model_name,
        n_draws = n_iter,
        n_locations = n_obs,
        components_used = c(
          base = TRUE,
          elevation = model_meta$has_elevation && !is.null(elevation),
          c4 = model_meta$has_c4 && !is.null(c4_percent),
          pft = model_meta$has_pft && !is.null(pft_tree),
          spatial = model_meta$has_gp
        )
      )
    ))
  } else {
    return(summary_df)
  }
}

#' Invert leaf wax d2H to precipitation d2H (uppercase wrapper for compatibility)
#' 
#' This is a wrapper function that maintains backward compatibility with code
#' that uses the uppercase function name and original parameter names.
#' 
#' @param d2H_wax Numeric vector of leaf wax d2H values (per mil)
#' @param d2H_wax_sd Numeric vector of measurement uncertainties (per mil)
#' @param longitude Numeric vector of longitudes (decimal degrees)
#' @param latitude Numeric vector of latitudes (decimal degrees)
#' @param elevation Numeric vector of elevations (meters)
#' @param elevation_sd Elevation uncertainty (not used, kept for compatibility)
#' @param c4_fraction Numeric vector of C4 vegetation percentage (0-100)
#' @param c4_fraction_sd C4 fraction uncertainty (not used, kept for compatibility)
#' @param pft_tree Numeric vector of tree PFT fraction (0-1)
#' @param pft_shrub Numeric vector of shrub PFT fraction (0-1)
#' @param pft_grass Numeric vector of grass PFT fraction (0-1)
#' @param model_name Character string specifying which model to use
#' @param n_posterior_draws Integer number of posterior draws to use
#' 
#' @return Same as invert_d2h
#' @export
invert_d2H <- function(d2H_wax, 
                      d2H_wax_sd,
                      longitude,
                      latitude,
                      elevation = NULL,
                      elevation_sd = 100,
                      c4_fraction = NULL,
                      c4_fraction_sd = 10,
                      pft_tree = NULL,
                      pft_shrub = NULL,
                      pft_grass = NULL,
                      model_name = "baseline",
                      n_posterior_draws = NULL) {
  
  # Map old parameter names to new ones
  invert_d2h(
    d2h_wax = d2H_wax,
    d2h_wax_err = d2H_wax_sd,
    longitude = longitude,
    latitude = latitude,
    elevation = elevation,
    c4_percent = c4_fraction,
    pft_tree = pft_tree,
    pft_shrub = pft_shrub,
    pft_grass = pft_grass,
    model_name = model_name,
    n_draws = n_posterior_draws,
    return_full = FALSE,
    credible_level = 0.9,
    verbose = TRUE
  )
}

#' Batch inversion for multiple samples
#' 
#' Convenience function to invert multiple samples with different models
#' and compare results.
#' 
#' @param data Data frame with columns matching invert_d2h arguments
#' @param models Character vector of model names to use
#' @param ... Additional arguments passed to invert_d2h
#' 
#' @return List of results from each model
#' @export
batch_invert_d2h <- function(data, models = c("baseline", "baseline_sp"), ...) {
  
  results <- list()
  
  for (model in models) {
    cat("\nRunning model:", model, "\n")
    
    # Handle missing columns gracefully
    args <- list(
      d2h_wax = data$d2h_wax,
      d2h_wax_err = if ("d2h_wax_err" %in% names(data)) data$d2h_wax_err else NULL,
      longitude = data$longitude,
      latitude = data$latitude,
      elevation = if ("elevation" %in% names(data)) data$elevation else NULL,
      c4_percent = if ("c4_percent" %in% names(data)) data$c4_percent else NULL,
      pft_tree = if ("pft_tree" %in% names(data)) data$pft_tree else NULL,
      pft_shrub = if ("pft_shrub" %in% names(data)) data$pft_shrub else NULL,
      pft_grass = if ("pft_grass" %in% names(data)) data$pft_grass else NULL,
      model_name = model
    )
    
    # Add any additional arguments
    args <- c(args, list(...))
    
    results[[model]] <- do.call(invert_d2h, args)
  }
  
  return(results)
}

#' Detect model capabilities from model name
#' 
#' @param model_name Name of the model
#' @return List of capability flags
#' @export
detect_model_capabilities <- function(model_name) {
  list(
    has_gp = grepl("sp", model_name),
    has_elevation = grepl("elev", model_name),
    has_c4 = grepl("c4", model_name),
    has_pft = grepl("pft", model_name)
  )
}