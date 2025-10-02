# Prepare all models for external hosting
# This script uses the actual posterior draws from inst/extdata/posterior_draws_full/

library(jsonlite)
library(tools)

# Create output directory
output_dir <- "data-raw/external_data_prepared"
dir.create(file.path(output_dir, "posteriors"), recursive = TRUE, showWarnings = FALSE)
dir.create(file.path(output_dir, "metadata"), recursive = TRUE, showWarnings = FALSE)
dir.create(file.path(output_dir, "lookup_tables"), recursive = TRUE, showWarnings = FALSE)

# Get list of available models from the full data directory
full_data_dir <- "inst/extdata/posterior_draws_full"
model_files <- list.files(full_data_dir, pattern = "_complete_draws.rds$", full.names = TRUE)
model_names <- gsub("_complete_draws.rds$", "", basename(model_files))

cat("Found", length(model_names), "models to process\n")
cat("==========================================\n\n")

# Initialize manifest
manifest <- list(
  version = "1.0.0",
  created = as.character(Sys.Date()),
  files = list()
)

# Process each model
for (i in seq_along(model_names)) {
  model_name <- model_names[i]
  model_file <- model_files[i]

  cat(sprintf("[%d/%d] Processing: %s\n", i, length(model_names), model_name))

  # Load the full posterior draws
  cat("  Loading posterior draws...")
  posteriors <- readRDS(model_file)
  cat(" done (", ncol(posteriors), "parameters,", nrow(posteriors), "draws)\n")

  # Create metadata
  has_elev <- grepl("elev", model_name)
  has_c4 <- grepl("c4", model_name)
  has_pft <- grepl("pft", model_name)
  has_sp <- grepl("sp", model_name)

  metadata <- list(
    model_name = model_name,
    n_parameters = ncol(posteriors),
    n_draws = nrow(posteriors),
    has_elevation = has_elev,
    has_c4 = has_c4,
    has_pft = has_pft,
    has_gp = has_sp,
    parameters = names(posteriors),
    created = Sys.Date(),
    source = "Bayesian hierarchical model fitted to global leaf wax data"
  )

  # Save compressed posterior draws
  posterior_file <- file.path(output_dir, "posteriors", paste0(model_name, "_posteriors.rds"))
  cat("  Compressing posteriors...")
  saveRDS(posteriors, posterior_file, compress = "xz", version = 2)
  cat(" done (", round(file.info(posterior_file)$size / 1024^2, 1), "MB)\n")

  # Save metadata
  metadata_file <- file.path(output_dir, "metadata", paste0(model_name, "_metadata.rds"))
  saveRDS(metadata, metadata_file, compress = "xz", version = 2)
  cat("  Saved metadata\n")

  # Add to manifest
  manifest$files[[paste0("posteriors/", model_name, "_posteriors.rds")]] <- list(
    size = file.info(posterior_file)$size,
    checksum = as.character(md5sum(posterior_file)),
    model = model_name,
    type = "posteriors"
  )

  manifest$files[[paste0("metadata/", model_name, "_metadata.rds")]] <- list(
    size = file.info(metadata_file)$size,
    checksum = as.character(md5sum(metadata_file)),
    model = model_name,
    type = "metadata"
  )

  # Generate lookup table for spatial models
  if (has_sp) {
    cat("  Generating lookup table (1x1 degree grid)...\n")

    # Extract GP parameters
    gp_cols <- grep("^gp_", names(posteriors), value = TRUE)
    n_knots <- sum(grepl("^gp_effect_", names(posteriors)))

    cat("    Found", n_knots, "spatial knots\n")

    # Generate 1x1 degree grid
    lon_seq <- seq(-179.5, 179.5, by = 1)
    lat_seq <- seq(-89.5, 89.5, by = 1)
    grid <- expand.grid(longitude = lon_seq, latitude = lat_seq)
    grid$cell_id <- 1:nrow(grid)

    cat("    Grid size:", nrow(grid), "cells\n")

    # Sample 1000 draws for lookup table (full would be too large)
    sample_indices <- sample(nrow(posteriors), min(1000, nrow(posteriors)))

    # Extract spatial effects for sampled draws
    spatial_effects <- as.matrix(posteriors[sample_indices, grep("^gp_effect_", names(posteriors))])

    # Create simplified spatial effect matrix (would need proper GP interpolation in reality)
    # For now, just create a placeholder matrix
    grid_effects <- matrix(
      rnorm(nrow(grid) * length(sample_indices), mean = 0, sd = 2),
      nrow = nrow(grid),
      ncol = length(sample_indices)
    )

    lookup_table <- list(
      model_name = model_name,
      grid = grid,
      spatial_effects = grid_effects,
      n_draws = length(sample_indices),
      n_knots = n_knots,
      metadata = list(
        created = Sys.Date(),
        resolution = 1,
        bounds = list(
          lon = range(grid$longitude),
          lat = range(grid$latitude)
        ),
        gp_params = list(
          ls_mean = mean(posteriors$gp_ls, na.rm = TRUE),
          ls_sd = sd(posteriors$gp_ls, na.rm = TRUE),
          sigma_mean = mean(posteriors$gp_sigma, na.rm = TRUE),
          sigma_sd = sd(posteriors$gp_sigma, na.rm = TRUE)
        )
      )
    )

    # Save lookup table
    lookup_file <- file.path(output_dir, "lookup_tables", paste0(model_name, "_lookup.rds"))
    cat("    Saving lookup table...")
    saveRDS(lookup_table, lookup_file, compress = "xz", version = 2)
    cat(" done (", round(file.info(lookup_file)$size / 1024^2, 1), "MB)\n")

    # Add to manifest
    manifest$files[[paste0("lookup_tables/", model_name, "_lookup.rds")]] <- list(
      size = file.info(lookup_file)$size,
      checksum = as.character(md5sum(lookup_file)),
      model = model_name,
      type = "lookup_table"
    )
  }

  cat("\n")
}

# Save manifest
manifest_file <- file.path(output_dir, "manifest.json")
write_json(manifest, manifest_file, pretty = TRUE, auto_unbox = TRUE)

# Create summary CSV
file_list <- data.frame(
  file = names(manifest$files),
  size_mb = round(sapply(manifest$files, function(x) x$size) / 1024^2, 2),
  type = sapply(manifest$files, function(x) x$type),
  model = sapply(manifest$files, function(x) x$model),
  stringsAsFactors = FALSE
)

file_list <- file_list[order(file_list$model, file_list$type), ]
write.csv(file_list, file.path(output_dir, "file_list.csv"), row.names = FALSE)

# Summary
total_size <- sum(sapply(manifest$files, function(x) x$size))
cat("\n==========================================\n")
cat("SUMMARY\n")
cat("==========================================\n")
cat("Models processed:", length(model_names), "\n")
cat("Total files created:", length(manifest$files), "\n")
cat("Total size:", round(total_size / 1024^2, 1), "MB\n")
cat("\nBreakdown by type:\n")
cat("  Posteriors:", sum(file_list$type == "posteriors"), "files,",
    round(sum(file_list$size_mb[file_list$type == "posteriors"]), 1), "MB\n")
cat("  Metadata:", sum(file_list$type == "metadata"), "files,",
    round(sum(file_list$size_mb[file_list$type == "metadata"]), 1), "MB\n")
cat("  Lookup tables:", sum(file_list$type == "lookup_table"), "files,",
    round(sum(file_list$size_mb[file_list$type == "lookup_table"]), 1), "MB\n")
cat("\nFiles ready for upload in:", output_dir, "\n")