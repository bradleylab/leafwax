# Script to extract spatial metadata from posterior files

library(jsonlite)

# List of spatial models
spatial_models <- c(
  "baseline_sp", "baseline_env_sp", "baseline_veg_sp",
  "c4_only_sp", "elevation_only_sp", "elevation_c4_sp",
  "elevation_c4_interact_sp", "full_sp", "full_interact_sp"
)

# Output directory
out_dir <- "inst/extdata/spatial_metadata"
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

# Function to generate knot locations (Fibonacci sphere)
generate_fibonacci_sphere <- function(n_points = 120) {
  golden_angle <- pi * (3.0 - sqrt(5.0))
  knot_coords <- matrix(NA, n_points, 2)

  for (i in 1:n_points) {
    theta <- golden_angle * (i - 1)
    z <- 1 - 2 * (i - 0.5) / n_points
    radius <- sqrt(1 - z^2)

    lat <- asin(z) * 180 / pi
    lon <- (theta %% (2 * pi)) * 180 / pi - 180

    knot_coords[i, ] <- c(lon, lat)
  }

  colnames(knot_coords) <- c("lon", "lat")
  return(knot_coords)
}

# Process each spatial model
all_metadata <- list()

for (model_name in spatial_models) {
  cat("Processing", model_name, "\n")

  # Load posterior draws
  post_file <- paste0("inst/extdata/posteriors/", model_name, "_posterior.rds")
  if (file.exists(post_file)) {
    draws <- readRDS(post_file)

    # Create metadata
    metadata <- list(
      model_name = model_name,
      n_draws = nrow(draws),
      parameters = names(draws),
      has_spatial = TRUE
    )

    # Check for spatial parameters
    spatial_params <- grep("^(lambda|ls_|sigma_.*spatial|effective_scale)", names(draws), value = TRUE)
    if (length(spatial_params) > 0) {
      metadata$spatial_params <- spatial_params

      # Extract ranges for key spatial parameters
      if ("lambda_decay" %in% names(draws)) {
        metadata$lambda_decay_range <- range(draws$lambda_decay)
      }
      if ("effective_scale_km" %in% names(draws)) {
        metadata$effective_scale_range <- range(draws$effective_scale_km)
      }
    }

    # Generate knot locations (standard 120 point Fibonacci sphere)
    # All spatial models use the same knot configuration
    knot_coords <- generate_fibonacci_sphere(120)
    metadata$n_knots <- nrow(knot_coords)

    # Save knot locations
    knot_file <- file.path(out_dir, paste0(model_name, "_knots.rds"))
    saveRDS(knot_coords, knot_file)
    cat("  Saved knot locations:", knot_file, "\n")

    # Add coordinate standardization info (will be computed at runtime from data)
    metadata$coordinate_info <- list(
      note = "Coordinates are standardized at runtime based on input data",
      knot_coords_file = paste0(model_name, "_knots.rds")
    )

    all_metadata[[model_name]] <- metadata

  } else {
    warning("File not found:", post_file)
  }
}

# Save combined metadata as JSON
json_file <- file.path(out_dir, "spatial_models_metadata.json")
write_json(all_metadata, json_file, pretty = TRUE, auto_unbox = TRUE)
cat("\nSaved spatial metadata to:", json_file, "\n")

# Also save as RDS for easier loading
rds_file <- file.path(out_dir, "spatial_models_metadata.rds")
saveRDS(all_metadata, rds_file)
cat("Saved spatial metadata to:", rds_file, "\n")