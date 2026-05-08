# R/lookup_integration.R - Integration of lookup tables with main inversion functions

#' Use lookup table in inversion (if available)
#'
#' Checks if a lookup table is available for the model and uses it
#' for faster spatial parameter computation.
#'
#' @param model_name Name of the model
#' @param longitude Longitude coordinates
#' @param latitude Latitude coordinates
#' @param cache_dir Directory where lookup tables are cached
#' @param method Interpolation method for lookup ("nearest" or "bilinear")
#' @return List with spatial parameters or NULL if no lookup table
#' @export
use_lookup_if_available <- function(model_name,
                                   longitude,
                                   latitude,
                                   cache_dir = NULL,
                                   method = "bilinear") {

  # Default cache directory
  if (is.null(cache_dir)) {
    cache_dir <- file.path(Sys.getenv("HOME"), ".leafwax_cache")
  }

  # Check if lookup table exists
  if (!dir.exists(cache_dir)) {
    return(NULL)
  }

  # Look for cached lookup tables for this model
  cache_files <- list.files(cache_dir,
                           pattern = paste0("lookup_", model_name, "_.*\\.rds"),
                           full.names = TRUE)

  if (length(cache_files) == 0) {
    return(NULL)
  }

  # Use the most recent cache file
  file_info <- file.info(cache_files)
  latest_file <- cache_files[which.max(file_info$mtime)]

  # Load lookup table
  tryCatch({
    lookup_table <- readRDS(latest_file)

    # Validate it
    if (!validate_lookup_table(lookup_table)) {
      return(NULL)
    }

    # Get spatial parameters
    spatial_params <- get_spatial_params(
      longitude = longitude,
      latitude = latitude,
      lookup_table = lookup_table,
      method = method,
      return_draws = TRUE
    )

    return(list(
      spatial_params = spatial_params,
      lookup_table = lookup_table,
      source = "lookup_table"
    ))

  }, error = function(e) {
    warning("Failed to use lookup table: ", e$message)
    return(NULL)
  })
}

#' Create optimized lookup table for region
#'
#' Creates a high-resolution lookup table for a specific region of interest.
#' This is useful when you need higher accuracy for a specific area.
#'
#' @param model_name Name of the model
#' @param lon_range Vector of length 2 with min and max longitude
#' @param lat_range Vector of length 2 with min and max latitude
#' @param resolution Grid resolution in degrees (default 0.5)
#' @param n_draws Number of posterior draws
#' @param cache_dir Directory to save the lookup table
#' @param verbose Logical indicating whether to print progress
#' @return Lookup table object
#' @export
#' @examples
#' \dontrun{
#' # Create high-res lookup for Western US
#' lookup_west <- create_regional_lookup(
#'   "baseline_sp",
#'   lon_range = c(-130, -100),
#'   lat_range = c(30, 50),
#'   resolution = 0.5
#' )
#' }
create_regional_lookup <- function(model_name,
                                  lon_range,
                                  lat_range,
                                  resolution = 0.5,
                                  n_draws = 100,
                                  cache_dir = NULL,
                                  verbose = TRUE) {

  if (length(lon_range) != 2 || length(lat_range) != 2) {
    stop("lon_range and lat_range must be vectors of length 2")
  }

  # Create regional grid
  if (verbose) {
    cat("Creating regional grid:\n")
    cat("  Longitude:", lon_range[1], "to", lon_range[2], "\n")
    cat("  Latitude:", lat_range[1], "to", lat_range[2], "\n")
    cat("  Resolution:", resolution, "degrees\n")
  }

  regional_grid <- generate_global_grid(
    lon_min = lon_range[1],
    lon_max = lon_range[2],
    lat_min = lat_range[1],
    lat_max = lat_range[2],
    resolution = resolution
  )

  if (verbose) {
    cat("  Grid cells:", nrow(regional_grid), "\n\n")
  }

  # Create lookup table
  lookup <- create_lookup_table(
    model_name = model_name,
    grid = regional_grid,
    n_draws = n_draws,
    cache_dir = cache_dir,
    verbose = verbose
  )

  return(lookup)
}

#' Benchmark lookup table vs direct computation
#'
#' Compares the speed and accuracy of lookup tables versus direct
#' spatial parameter computation.
#'
#' @param model_name Name of the model
#' @param n_locations Number of random test locations
#' @param lookup_table Pre-computed lookup table (NULL to create one)
#' @param verbose Logical indicating whether to print results
#' @return List with benchmark results
#' @export
benchmark_lookup <- function(model_name,
                           n_locations = 100,
                           lookup_table = NULL,
                           verbose = TRUE) {

  # Generate random test locations
  set.seed(42)
  test_lons <- runif(n_locations, -180, 180)
  test_lats <- runif(n_locations, -60, 60)  # Avoid poles

  # Standardize coordinates
  coords_std <- cbind(test_lons / 180, test_lats / 90)

  # Load model for direct computation
  model <- load_posteriors(model_name, n_draws = 100, verbose = FALSE)

  if (!model$metadata$has_gp) {
    stop("Model ", model_name, " does not have spatial components")
  }

  # Create lookup table if not provided
  if (is.null(lookup_table)) {
    if (verbose) cat("Creating lookup table...\n")
    lookup_table <- create_lookup_table(
      model_name = model_name,
      n_draws = 100,
      verbose = FALSE
    )
  }

  # Extract parameters for direct computation
  draws <- model$draws
  knot_coords <- model$metadata$knot_coords

  # Get GP parameters (simplified extraction)
  if ("ls_gp" %in% colnames(draws)) {
    ls_gp_draws <- draws[, "ls_gp"]
  } else {
    ls_gp_draws <- draws[, "ls"]
  }

  if ("sigma_gp" %in% colnames(draws)) {
    sigma_gp_draws <- draws[, "sigma_gp"]
  } else {
    sigma_gp_draws <- draws[, "sigma"]
  }

  z_cols <- grep("^z_spatial\\[|^z\\[", colnames(draws), value = TRUE)
  z_spatial_draws <- as.matrix(draws[, z_cols])

  # Benchmark direct computation
  if (verbose) cat("Benchmarking direct computation...\n")
  t1 <- Sys.time()
  direct_results <- matrix(NA, n_locations, nrow(draws))
  for (i in seq_len(n_locations)) {
    direct_results[i, ] <- predict_spatial_mpp(
      coords_std = coords_std[i, ],
      knot_coords = knot_coords / c(180, 90),
      z_spatial_draws = z_spatial_draws,
      ls_gp_draws = ls_gp_draws,
      sigma_gp_draws = sigma_gp_draws
    )
  }
  direct_time <- as.numeric(Sys.time() - t1, units = "secs")

  # Benchmark lookup table (nearest neighbor)
  if (verbose) cat("Benchmarking lookup table (nearest)...\n")
  t1 <- Sys.time()
  lookup_nearest <- get_spatial_params(
    longitude = test_lons,
    latitude = test_lats,
    lookup_table = lookup_table,
    method = "nearest",
    return_draws = TRUE
  )
  lookup_nearest_time <- as.numeric(Sys.time() - t1, units = "secs")

  # Benchmark lookup table (bilinear)
  if (verbose) cat("Benchmarking lookup table (bilinear)...\n")
  t1 <- Sys.time()
  lookup_bilinear <- get_spatial_params(
    longitude = test_lons,
    latitude = test_lats,
    lookup_table = lookup_table,
    method = "bilinear",
    return_draws = TRUE
  )
  lookup_bilinear_time <- as.numeric(Sys.time() - t1, units = "secs")

  # Compute accuracy metrics
  rmse_nearest <- sqrt(mean((lookup_nearest - direct_results)^2))
  rmse_bilinear <- sqrt(mean((lookup_bilinear - direct_results)^2))
  mae_nearest <- mean(abs(lookup_nearest - direct_results))
  mae_bilinear <- mean(abs(lookup_bilinear - direct_results))

  # Correlation
  cor_nearest <- cor(as.vector(lookup_nearest), as.vector(direct_results))
  cor_bilinear <- cor(as.vector(lookup_bilinear), as.vector(direct_results))

  results <- list(
    timings = data.frame(
      method = c("Direct", "Lookup (nearest)", "Lookup (bilinear)"),
      time_seconds = c(direct_time, lookup_nearest_time, lookup_bilinear_time),
      speedup = c(1, direct_time/lookup_nearest_time, direct_time/lookup_bilinear_time)
    ),
    accuracy = data.frame(
      method = c("Lookup (nearest)", "Lookup (bilinear)"),
      rmse = c(rmse_nearest, rmse_bilinear),
      mae = c(mae_nearest, mae_bilinear),
      correlation = c(cor_nearest, cor_bilinear)
    ),
    n_locations = n_locations,
    model = model_name
  )

  if (verbose) {
    cat("\n==== Benchmark Results ====\n")
    cat("\nTimings:\n")
    print(results$timings)
    cat("\nAccuracy (vs direct computation):\n")
    print(results$accuracy)
    cat("\nSummary:\n")
    cat("  Lookup (nearest) is", sprintf("%.1fx", results$timings$speedup[2]),
        "faster\n")
    cat("  Lookup (bilinear) is", sprintf("%.1fx", results$timings$speedup[3]),
        "faster\n")
    cat("  Bilinear interpolation correlation:", sprintf("%.4f", cor_bilinear), "\n")
  }

  return(invisible(results))
}