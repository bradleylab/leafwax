# R/lookup_tables.R - Lookup table system for spatial parameters

#' @importFrom stats approx
NULL

#' Generate global 1x1 degree grid
#'
#' Creates a regular grid of longitude and latitude coordinates
#' at 1-degree resolution covering the entire globe.
#'
#' @param lon_min Minimum longitude (default -180)
#' @param lon_max Maximum longitude (default 180)
#' @param lat_min Minimum latitude (default -90)
#' @param lat_max Maximum latitude (default 90)
#' @param resolution Grid resolution in degrees (default 1)
#' @return Data frame with columns lon, lat, cell_id
#' @export
#' @examples
#' \dontrun{
#' grid <- generate_global_grid()
#' head(grid)
#' }
generate_global_grid <- function(lon_min = -180, lon_max = 180,
                                lat_min = -90, lat_max = 90,
                                resolution = 1) {

  # Create sequences for longitude and latitude
  lon_seq <- seq(from = lon_min + resolution/2,
                 to = lon_max - resolution/2,
                 by = resolution)
  lat_seq <- seq(from = lat_min + resolution/2,
                 to = lat_max - resolution/2,
                 by = resolution)

  # Create grid
  grid <- expand.grid(lon = lon_seq, lat = lat_seq)

  # Add cell ID for fast lookup
  grid$cell_id <- seq_len(nrow(grid))

  # Add row and column indices for easier navigation
  grid$lon_idx <- match(grid$lon, lon_seq)
  grid$lat_idx <- match(grid$lat, lat_seq)

  return(grid)
}

#' Create lookup table for spatial parameters
#'
#' Pre-computes spatial effects for each grid cell using a model's
#' spatial parameters (GP knots, length scale, variance).
#'
#' @param model_name Name of the model to create lookup table for
#' @param grid Data frame with lon/lat coordinates (default global 1x1 grid)
#' @param n_draws Number of posterior draws to use (NULL for all)
#' @param cache_dir Directory to save cached lookup tables (NULL for no caching)
#' @param verbose Logical indicating whether to print progress
#' @return List containing lookup table and metadata
#' @export
#' @examples
#' \dontrun{
#' lookup <- create_lookup_table("baseline_sp")
#' str(lookup)
#' }
create_lookup_table <- function(model_name,
                               grid = NULL,
                               n_draws = 100,
                               cache_dir = NULL,
                               verbose = TRUE) {

  # Check for cached version first
  if (!is.null(cache_dir)) {
    cache_file <- file.path(cache_dir,
                           paste0("lookup_", model_name, "_",
                                 n_draws, "draws.rds"))
    if (file.exists(cache_file)) {
      if (verbose) cat("Loading cached lookup table from", cache_file, "\n")
      return(readRDS(cache_file))
    }
  }

  # Load model posteriors
  if (verbose) cat("Loading model posteriors for", model_name, "\n")
  model <- load_posteriors(model_name, n_draws = n_draws, verbose = FALSE)

  # Check if model has spatial component
  if (!model$metadata$has_gp) {
    stop("Model ", model_name, " does not have spatial components. ",
         "Lookup tables are only needed for spatial models.")
  }

  # Use default global grid if not provided
  if (is.null(grid)) {
    if (verbose) cat("Generating global 1x1 degree grid\n")
    grid <- generate_global_grid()
  }

  # Extract spatial parameters
  draws <- model$draws
  knot_coords <- model$metadata$knot_coords

  # Get GP parameters
  if ("ls_gp" %in% colnames(draws)) {
    ls_gp_draws <- draws[, "ls_gp"]
  } else if ("ls" %in% colnames(draws)) {
    ls_gp_draws <- draws[, "ls"]
  } else {
    stop("Could not find GP length scale parameter in model draws")
  }

  if ("sigma_gp" %in% colnames(draws)) {
    sigma_gp_draws <- draws[, "sigma_gp"]
  } else if ("sigma" %in% colnames(draws)) {
    # May need to extract and scale
    sigma_gp_draws <- draws[, "sigma"]
    if ("sigma_gp_raw[1]" %in% colnames(draws)) {
      # Scale by sigma if needed
      sigma_gp_draws <- sigma_gp_draws * draws[, "sigma_gp_raw[1]"]
    }
  } else {
    stop("Could not find GP variance parameter in model draws")
  }

  # Extract spatial random effects at knots
  z_cols <- grep("^z_spatial\\[|^z\\[", colnames(draws), value = TRUE)
  if (length(z_cols) == 0) {
    stop("Could not find spatial random effects in model draws")
  }
  z_spatial_draws <- as.matrix(draws[, z_cols])

  # Ensure we have the right number of knots
  if (ncol(z_spatial_draws) != nrow(knot_coords)) {
    stop("Mismatch between number of spatial effects (", ncol(z_spatial_draws),
         ") and number of knots (", nrow(knot_coords), ")")
  }

  # Pre-compute spatial effects for each grid cell
  if (verbose) {
    cat("Pre-computing spatial effects for", nrow(grid), "grid cells\n")
    pb <- txtProgressBar(min = 0, max = nrow(grid), style = 3)
  }

  spatial_effects <- matrix(NA, nrow = nrow(grid), ncol = nrow(draws))

  for (i in seq_len(nrow(grid))) {
    # Standardize coordinates (simple standardization for now)
    coords_std <- c(grid$lon[i] / 180, grid$lat[i] / 90)

    # Compute spatial effect using predict_spatial_mpp
    spatial_effects[i, ] <- predict_spatial_mpp(
      coords_std = coords_std,
      knot_coords = knot_coords / c(180, 90),  # Standardize knot coords
      z_spatial_draws = z_spatial_draws,
      ls_gp_draws = ls_gp_draws,
      sigma_gp_draws = sigma_gp_draws
    )

    if (verbose) setTxtProgressBar(pb, i)
  }

  if (verbose) {
    close(pb)
    cat("\nSpatial effects computed successfully\n")
  }

  # Create lookup table structure
  lookup_table <- list(
    model_name = model_name,
    grid = grid,
    spatial_effects = spatial_effects,
    n_draws = nrow(draws),
    metadata = list(
      created = Sys.time(),
      resolution = ifelse(nrow(grid) > 1,
                         grid$lon[2] - grid$lon[1],
                         1),
      bounds = list(
        lon = range(grid$lon),
        lat = range(grid$lat)
      ),
      gp_params = list(
        ls_mean = mean(ls_gp_draws),
        ls_sd = sd(ls_gp_draws),
        sigma_mean = mean(sigma_gp_draws),
        sigma_sd = sd(sigma_gp_draws)
      )
    )
  )

  class(lookup_table) <- c("leafwax_lookup_table", "list")

  # Cache if requested
  if (!is.null(cache_dir)) {
    if (!dir.exists(cache_dir)) {
      dir.create(cache_dir, recursive = TRUE)
    }
    if (verbose) cat("Saving lookup table to", cache_file, "\n")
    saveRDS(lookup_table, cache_file)
  }

  return(lookup_table)
}

#' Get spatial parameters from lookup table
#'
#' Retrieves pre-computed spatial parameters for given coordinates
#' using nearest neighbor or bilinear interpolation.
#'
#' @param longitude Numeric vector of longitudes
#' @param latitude Numeric vector of latitudes
#' @param lookup_table Lookup table created by create_lookup_table()
#' @param method Interpolation method ("nearest" or "bilinear")
#' @param return_draws Logical whether to return all draws or just summary
#' @return Matrix of spatial effects (locations x draws) or summary statistics
#' @export
#' @examples
#' \dontrun{
#' lookup <- create_lookup_table("baseline_sp")
#' effects <- get_spatial_params(c(-120, -100), c(40, 35), lookup)
#' }
get_spatial_params <- function(longitude, latitude, lookup_table,
                              method = c("nearest", "bilinear"),
                              return_draws = TRUE) {

  method <- match.arg(method)

  # Validate inputs
  if (!inherits(lookup_table, "leafwax_lookup_table")) {
    stop("lookup_table must be created by create_lookup_table()")
  }

  if (length(longitude) != length(latitude)) {
    stop("longitude and latitude must have the same length")
  }

  n_locations <- length(longitude)
  n_draws <- ncol(lookup_table$spatial_effects)

  # Initialize output matrix
  spatial_params <- matrix(NA, nrow = n_locations, ncol = n_draws)

  for (i in seq_len(n_locations)) {
    lon <- longitude[i]
    lat <- latitude[i]

    # Handle longitude wrapping
    while (lon < -180) lon <- lon + 360
    while (lon > 180) lon <- lon - 360

    # Clip latitude to valid range
    lat <- max(-90, min(90, lat))

    if (method == "nearest") {
      # Find nearest grid cell
      distances <- sqrt((lookup_table$grid$lon - lon)^2 +
                       (lookup_table$grid$lat - lat)^2)
      nearest_idx <- which.min(distances)
      spatial_params[i, ] <- lookup_table$spatial_effects[nearest_idx, ]

    } else if (method == "bilinear") {
      # Bilinear interpolation between four nearest grid cells
      resolution <- lookup_table$metadata$resolution

      # Find surrounding grid cells
      lon_idx <- (lon - min(lookup_table$grid$lon)) / resolution + 1
      lat_idx <- (lat - min(lookup_table$grid$lat)) / resolution + 1

      # Get indices of four corners
      lon_low <- floor(lon_idx)
      lon_high <- ceiling(lon_idx)
      lat_low <- floor(lat_idx)
      lat_high <- ceiling(lat_idx)

      # Handle edge cases
      max_lon_idx <- max(lookup_table$grid$lon_idx)
      max_lat_idx <- max(lookup_table$grid$lat_idx)

      lon_low <- max(1, min(lon_low, max_lon_idx))
      lon_high <- max(1, min(lon_high, max_lon_idx))
      lat_low <- max(1, min(lat_low, max_lat_idx))
      lat_high <- max(1, min(lat_high, max_lat_idx))

      # Get grid cell indices
      idx_ll <- which(lookup_table$grid$lon_idx == lon_low &
                     lookup_table$grid$lat_idx == lat_low)
      idx_lh <- which(lookup_table$grid$lon_idx == lon_low &
                     lookup_table$grid$lat_idx == lat_high)
      idx_hl <- which(lookup_table$grid$lon_idx == lon_high &
                     lookup_table$grid$lat_idx == lat_low)
      idx_hh <- which(lookup_table$grid$lon_idx == lon_high &
                     lookup_table$grid$lat_idx == lat_high)

      # If any index is missing, fall back to nearest neighbor
      if (length(idx_ll) == 0 || length(idx_lh) == 0 ||
          length(idx_hl) == 0 || length(idx_hh) == 0) {
        distances <- sqrt((lookup_table$grid$lon - lon)^2 +
                         (lookup_table$grid$lat - lat)^2)
        nearest_idx <- which.min(distances)
        spatial_params[i, ] <- lookup_table$spatial_effects[nearest_idx, ]
      } else {
        # Compute weights
        lon_weight <- lon_idx - lon_low
        lat_weight <- lat_idx - lat_low

        # Bilinear interpolation
        for (j in seq_len(n_draws)) {
          v_ll <- lookup_table$spatial_effects[idx_ll, j]
          v_lh <- lookup_table$spatial_effects[idx_lh, j]
          v_hl <- lookup_table$spatial_effects[idx_hl, j]
          v_hh <- lookup_table$spatial_effects[idx_hh, j]

          v_l <- v_ll * (1 - lat_weight) + v_lh * lat_weight
          v_h <- v_hl * (1 - lat_weight) + v_hh * lat_weight

          spatial_params[i, j] <- v_l * (1 - lon_weight) + v_h * lon_weight
        }
      }
    }
  }

  if (return_draws) {
    return(spatial_params)
  } else {
    # Return summary statistics
    summary_stats <- data.frame(
      longitude = longitude,
      latitude = latitude,
      spatial_mean = rowMeans(spatial_params),
      spatial_median = apply(spatial_params, 1, median),
      spatial_sd = apply(spatial_params, 1, sd),
      spatial_q025 = apply(spatial_params, 1, quantile, probs = 0.025),
      spatial_q975 = apply(spatial_params, 1, quantile, probs = 0.975)
    )
    return(summary_stats)
  }
}

#' Cache all lookup tables for available spatial models
#'
#' Pre-computes and caches lookup tables for all spatial models in the package.
#' This is useful for deployment or when you want to pre-generate all tables.
#'
#' @param cache_dir Directory to save cached lookup tables
#' @param n_draws Number of posterior draws to use for each model
#' @param models Character vector of model names (NULL for all spatial models)
#' @param verbose Logical indicating whether to print progress
#' @return Invisible NULL
#' @export
#' @examples
#' \dontrun{
#' cache_all_lookup_tables("~/leafwax_cache", n_draws = 100)
#' }
cache_all_lookup_tables <- function(cache_dir,
                                   n_draws = 100,
                                   models = NULL,
                                   verbose = TRUE) {

  # Get list of models if not provided
  if (is.null(models)) {
    all_models <- available_models()

    # Filter for spatial models only
    models <- character()
    for (model in all_models) {
      info <- get_model_info(model)
      if (isTRUE(info$has_spatial) || isTRUE(info$has_gp)) {
        models <- c(models, model)
      }
    }
  }

  if (length(models) == 0) {
    if (verbose) cat("No spatial models found to cache\n")
    return(invisible(NULL))
  }

  if (verbose) {
    cat("Caching lookup tables for", length(models), "spatial models\n")
    cat("Cache directory:", cache_dir, "\n")
  }

  # Create cache directory if it doesn't exist
  if (!dir.exists(cache_dir)) {
    dir.create(cache_dir, recursive = TRUE)
  }

  # Generate lookup table for each model
  for (model in models) {
    if (verbose) {
      cat("\n", strrep("=", 50), "\n")
      cat("Processing model:", model, "\n")
    }

    tryCatch({
      lookup <- create_lookup_table(
        model_name = model,
        n_draws = n_draws,
        cache_dir = cache_dir,
        verbose = verbose
      )

      if (verbose) {
        cat("Successfully cached lookup table for", model, "\n")
      }
    }, error = function(e) {
      warning("Failed to create lookup table for model ", model, ": ", e$message)
    })
  }

  if (verbose) {
    cat("\n", strrep("=", 50), "\n")
    cat("Caching complete. Tables saved to:", cache_dir, "\n")
  }

  return(invisible(NULL))
}

#' Print method for lookup tables
#'
#' @param x A leafwax_lookup_table object
#' @param ... Additional arguments (not used)
#' @export
print.leafwax_lookup_table <- function(x, ...) {
  cat("Leafwax Lookup Table\n")
  cat(strrep("-", 40), "\n")
  cat("Model:", x$model_name, "\n")
  cat("Grid cells:", nrow(x$grid), "\n")
  cat("Resolution:", x$metadata$resolution, "degrees\n")
  cat("Bounds:\n")
  cat("  Longitude:", x$metadata$bounds$lon[1], "to", x$metadata$bounds$lon[2], "\n")
  cat("  Latitude:", x$metadata$bounds$lat[1], "to", x$metadata$bounds$lat[2], "\n")
  cat("Posterior draws:", x$n_draws, "\n")
  cat("Created:", format(x$metadata$created), "\n")
  cat("\nGP Parameters (mean +/- sd):\n")
  cat("  Length scale:",
      sprintf("%.2f +/- %.2f",
              x$metadata$gp_params$ls_mean,
              x$metadata$gp_params$ls_sd), "\n")
  cat("  Variance:",
      sprintf("%.2f +/- %.2f",
              x$metadata$gp_params$sigma_mean,
              x$metadata$gp_params$sigma_sd), "\n")
}

#' Validate lookup table
#'
#' Checks that a lookup table is valid and contains all required components.
#'
#' @param lookup_table Object to validate
#' @return Logical TRUE if valid, otherwise throws an error
#' @export
validate_lookup_table <- function(lookup_table) {

  if (!inherits(lookup_table, "leafwax_lookup_table")) {
    stop("Object is not a leafwax_lookup_table")
  }

  required_fields <- c("model_name", "grid", "spatial_effects", "n_draws", "metadata")
  missing_fields <- setdiff(required_fields, names(lookup_table))

  if (length(missing_fields) > 0) {
    stop("Lookup table is missing required fields: ",
         paste(missing_fields, collapse = ", "))
  }

  # Check dimensions
  if (nrow(lookup_table$grid) != nrow(lookup_table$spatial_effects)) {
    stop("Mismatch between grid size and spatial effects matrix")
  }

  # Check for NAs in critical fields
  if (any(is.na(lookup_table$grid$lon)) || any(is.na(lookup_table$grid$lat))) {
    stop("Grid contains NA coordinates")
  }

  if (all(is.na(lookup_table$spatial_effects))) {
    stop("All spatial effects are NA")
  }

  return(TRUE)
}