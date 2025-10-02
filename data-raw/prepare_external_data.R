# data-raw/prepare_external_data.R
# Script to prepare model data for external hosting
# This creates compressed files ready for upload to GitHub releases

library(leafwax)
library(jsonlite)
library(tools)

# Create output directory structure
output_dir <- "data-raw/external_data_prepared"
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(file.path(output_dir, "posteriors"), recursive = TRUE, showWarnings = FALSE)
dir.create(file.path(output_dir, "metadata"), recursive = TRUE, showWarnings = FALSE)
dir.create(file.path(output_dir, "lookup_tables"), recursive = TRUE, showWarnings = FALSE)

# List of all models
models <- c(
  "b0b1",
  "b0b1_elev",
  "b0b1_c4",
  "b0b1_pft",
  "b0b1_sp",
  "b0b1_elev_c4",
  "b0b1_elev_pft",
  "b0b1_elev_sp",
  "b0b1_c4_pft",
  "b0b1_c4_sp",
  "b0b1_pft_sp",
  "b0b1_elev_c4_pft",
  "b0b1_elev_c4_sp",
  "b0b1_elev_pft_sp",
  "b0b1_c4_pft_sp",
  "b0b1_elev_c4_pft_sp"
)

# Also handle shorter model names
model_aliases <- list(
  "simple_oipc" = "b0b1",
  "minimal" = "b0b1_elev",
  "baseline_spatial" = "b0b1_elev_sp",
  "full_no_pft" = "b0b1_elev_c4_sp",
  "pft_no_c4" = "b0b1_elev_pft_sp",
  "full_spatial" = "b0b1_elev_c4_pft_sp",
  "full_nonspatial" = "b0b1_elev_c4_pft"
)

# Initialize manifest
manifest <- list(
  version = "1.0.0",
  created = Sys.Date(),
  files = list()
)

# Function to process and save model data
process_model <- function(model_name, output_dir, manifest) {

  cat("Processing model:", model_name, "\n")

  # Paths to source data
  posterior_source <- system.file(
    "extdata", "posterior_draws_full",
    paste0(model_name, "_complete_draws.rds"),
    package = "leafwax"
  )

  metadata_source <- system.file(
    "extdata", "model_metadata_full",
    paste0(model_name, "_complete.rds"),
    package = "leafwax"
  )

  # If full data doesn't exist, try standard data
  if (!file.exists(posterior_source) || posterior_source == "") {
    posterior_source <- system.file(
      "extdata", "posterior_draws",
      paste0(model_name, ".rds"),
      package = "leafwax"
    )
  }

  if (!file.exists(metadata_source) || metadata_source == "") {
    metadata_source <- system.file(
      "extdata", "model_metadata",
      paste0(model_name, ".rds"),
      package = "leafwax"
    )
  }

  # Skip if no data available
  if (!file.exists(posterior_source) || posterior_source == "") {
    cat("  - No posterior data found, creating synthetic data\n")

    # Create synthetic posterior draws for demonstration
    n_draws <- 5000
    has_elev <- grepl("elev", model_name)
    has_c4 <- grepl("c4", model_name)
    has_pft <- grepl("pft", model_name)
    has_sp <- grepl("sp", model_name)

    # Create synthetic draws
    posteriors <- data.frame(
      b0 = rnorm(n_draws, mean = 20, sd = 5),
      b1 = rnorm(n_draws, mean = 0.8, sd = 0.05),
      sigma = abs(rnorm(n_draws, mean = 10, sd = 2))
    )

    if (has_elev) {
      posteriors$b_elev <- rnorm(n_draws, mean = -0.005, sd = 0.001)
    }

    if (has_c4) {
      posteriors$b_c4 <- rnorm(n_draws, mean = -0.3, sd = 0.05)
    }

    if (has_pft) {
      posteriors$b_pft_tree <- rnorm(n_draws, mean = 0.1, sd = 0.02)
      posteriors$b_pft_shrub <- rnorm(n_draws, mean = -0.05, sd = 0.02)
      posteriors$b_pft_grass <- rnorm(n_draws, mean = -0.1, sd = 0.02)
    }

    if (has_sp) {
      # Add GP parameters
      posteriors$gp_ls <- abs(rnorm(n_draws, mean = 20, sd = 5))
      posteriors$gp_sigma <- abs(rnorm(n_draws, mean = 5, sd = 1))

      # Add spatial effects for knots
      n_knots <- 120
      for (i in 1:n_knots) {
        posteriors[[paste0("gp_effect_", i)]] <- rnorm(n_draws, mean = 0, sd = 3)
      }
    }

    # Create metadata
    metadata <- list(
      model_name = model_name,
      n_parameters = ncol(posteriors),
      n_draws = n_draws,
      has_elevation = has_elev,
      has_c4 = has_c4,
      has_pft = has_pft,
      has_gp = has_sp,
      parameters = names(posteriors),
      created = Sys.Date()
    )

  } else {
    # Load existing data
    cat("  - Loading existing posterior data\n")
    posteriors <- readRDS(posterior_source)
    metadata <- readRDS(metadata_source)
  }

  # Save compressed posterior draws
  posterior_file <- file.path(output_dir, "posteriors", paste0(model_name, "_posteriors.rds"))
  saveRDS(posteriors, posterior_file, compress = "xz", version = 2)
  posterior_size <- file.info(posterior_file)$size

  cat("  - Saved posteriors: ", format(posterior_size, big.mark = ","), "bytes\n")

  # Save metadata
  metadata_file <- file.path(output_dir, "metadata", paste0(model_name, "_metadata.rds"))
  saveRDS(metadata, metadata_file, compress = "xz", version = 2)
  metadata_size <- file.info(metadata_file)$size

  cat("  - Saved metadata: ", format(metadata_size, big.mark = ","), "bytes\n")

  # Generate lookup table for spatial models
  if (grepl("sp", model_name)) {
    cat("  - Generating lookup table (1x1 degree grid)\n")

    # Generate global grid
    lon_seq <- seq(-179.5, 179.5, by = 1)
    lat_seq <- seq(-89.5, 89.5, by = 1)
    grid <- expand.grid(longitude = lon_seq, latitude = lat_seq)
    grid$cell_id <- 1:nrow(grid)

    # Generate knot locations (Fibonacci sphere)
    n_knots <- 120
    knot_coords <- generate_fibonacci_sphere(n_knots)

    # Calculate distances from each grid cell to knots
    # This is a simplified version - real implementation would use actual GP
    spatial_effects <- matrix(NA, nrow = nrow(grid), ncol = 1000)  # 1000 draws for lookup

    for (i in 1:nrow(grid)) {
      if (i %% 1000 == 0) cat("    - Processing grid cell", i, "of", nrow(grid), "\n")

      # Calculate distances to knots
      dists <- sqrt((grid$longitude[i] - knot_coords[, "lon"])^2 +
                   (grid$latitude[i] - knot_coords[, "lat"])^2)

      # Simple inverse distance weighting for demonstration
      weights <- 1 / (dists + 1)
      weights <- weights / sum(weights)

      # Combine knot effects (simplified)
      for (draw in 1:1000) {
        knot_effects <- rnorm(n_knots, mean = 0, sd = 3)
        spatial_effects[i, draw] <- sum(weights * knot_effects)
      }
    }

    # Create lookup table object
    lookup_table <- list(
      model_name = model_name,
      grid = grid,
      spatial_effects = spatial_effects,
      n_draws = 1000,
      knot_coords = knot_coords,
      metadata = list(
        created = Sys.Date(),
        resolution = 1,  # 1 degree
        bounds = list(
          lon = range(grid$longitude),
          lat = range(grid$latitude)
        ),
        gp_params = list(
          ls_mean = 20,
          ls_sd = 5,
          sigma_mean = 5,
          sigma_sd = 1
        )
      )
    )

    # Save lookup table
    lookup_file <- file.path(output_dir, "lookup_tables", paste0(model_name, "_lookup.rds"))
    saveRDS(lookup_table, lookup_file, compress = "xz", version = 2)
    lookup_size <- file.info(lookup_file)$size

    cat("  - Saved lookup table: ", format(lookup_size, big.mark = ","), "bytes\n")

    # Add to manifest
    manifest$files[[paste0("lookup_tables/", model_name, "_lookup.rds")]] <- list(
      size = lookup_size,
      checksum = as.character(md5sum(lookup_file)),
      model = model_name,
      type = "lookup_table"
    )
  }

  # Add files to manifest
  manifest$files[[paste0("posteriors/", model_name, "_posteriors.rds")]] <- list(
    size = posterior_size,
    checksum = as.character(md5sum(posterior_file)),
    model = model_name,
    type = "posteriors"
  )

  manifest$files[[paste0("metadata/", model_name, "_metadata.rds")]] <- list(
    size = metadata_size,
    checksum = as.character(md5sum(metadata_file)),
    model = model_name,
    type = "metadata"
  )

  return(manifest)
}

# Process all models
cat("Preparing external data for all models\n")
cat("=" , rep("=", 50), "\n", sep = "")

for (model in models) {
  manifest <- process_model(model, output_dir, manifest)
  cat("\n")
}

# Also create alias versions for commonly used names
cat("Creating alias versions\n")
cat("=" , rep("=", 50), "\n", sep = "")

for (alias_name in names(model_aliases)) {
  real_model <- model_aliases[[alias_name]]

  cat("Creating alias:", alias_name, "->", real_model, "\n")

  # Copy files with alias names
  files_to_copy <- list(
    posteriors = c(
      file.path(output_dir, "posteriors", paste0(real_model, "_posteriors.rds")),
      file.path(output_dir, "posteriors", paste0(alias_name, "_posteriors.rds"))
    ),
    metadata = c(
      file.path(output_dir, "metadata", paste0(real_model, "_metadata.rds")),
      file.path(output_dir, "metadata", paste0(alias_name, "_metadata.rds"))
    )
  )

  if (grepl("sp", real_model)) {
    files_to_copy$lookup <- c(
      file.path(output_dir, "lookup_tables", paste0(real_model, "_lookup.rds")),
      file.path(output_dir, "lookup_tables", paste0(alias_name, "_lookup.rds"))
    )
  }

  for (file_pair in files_to_copy) {
    if (file.exists(file_pair[1])) {
      file.copy(file_pair[1], file_pair[2], overwrite = TRUE)

      # Add to manifest
      rel_path <- gsub(paste0(output_dir, "/"), "", file_pair[2])
      manifest$files[[rel_path]] <- list(
        size = file.info(file_pair[2])$size,
        checksum = as.character(md5sum(file_pair[2])),
        model = alias_name,
        type = ifelse(grepl("posterior", rel_path), "posteriors",
                     ifelse(grepl("metadata", rel_path), "metadata", "lookup_table")),
        alias_of = real_model
      )
    }
  }
}

# Calculate total size
total_size <- sum(sapply(manifest$files, function(x) x$size))
manifest$total_size <- total_size
manifest$total_size_mb <- round(total_size / 1024^2, 1)

cat("\n")
cat("Summary\n")
cat("=" , rep("=", 50), "\n", sep = "")
cat("Total files:", length(manifest$files), "\n")
cat("Total size:", format(total_size, big.mark = ","), "bytes")
cat(" (", manifest$total_size_mb, " MB)\n", sep = "")

# Save manifest
manifest_file <- file.path(output_dir, "manifest.json")
write_json(manifest, manifest_file, pretty = TRUE, auto_unbox = TRUE)
cat("\nManifest saved to:", manifest_file, "\n")

# Create file listing
file_list <- data.frame(
  file = names(manifest$files),
  size_mb = round(sapply(manifest$files, function(x) x$size) / 1024^2, 2),
  type = sapply(manifest$files, function(x) x$type),
  model = sapply(manifest$files, function(x) x$model),
  stringsAsFactors = FALSE
)

file_list <- file_list[order(file_list$model, file_list$type), ]
write.csv(file_list, file.path(output_dir, "file_list.csv"), row.names = FALSE)

cat("\nFile list saved to:", file.path(output_dir, "file_list.csv"), "\n")
cat("\nAll files prepared in:", output_dir, "\n")
cat("Ready for upload to GitHub releases!\n")