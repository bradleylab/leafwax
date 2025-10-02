# data-raw/prepare_external_data_quick.R
# Quick version that prepares just a few example models

library(jsonlite)
library(tools)

# Create output directory structure
output_dir <- "data-raw/external_data_prepared"
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(file.path(output_dir, "posteriors"), recursive = TRUE, showWarnings = FALSE)
dir.create(file.path(output_dir, "metadata"), recursive = TRUE, showWarnings = FALSE)
dir.create(file.path(output_dir, "lookup_tables"), recursive = TRUE, showWarnings = FALSE)

# Just process a few example models
models <- c("b0b1", "b0b1_sp", "b0b1_elev_sp")

# Initialize manifest
manifest <- list(
  version = "1.0.0",
  created = as.character(Sys.Date()),
  files = list()
)

cat("Preparing external data for example models\n")
cat("==========================================\n\n")

for (model_name in models) {
  cat("Processing model:", model_name, "\n")

  # Generate synthetic data
  n_draws <- 5000
  has_elev <- grepl("elev", model_name)
  has_sp <- grepl("sp", model_name)

  # Create synthetic posterior draws
  posteriors <- data.frame(
    b0 = rnorm(n_draws, mean = 20, sd = 5),
    b1 = rnorm(n_draws, mean = 0.8, sd = 0.05),
    sigma = abs(rnorm(n_draws, mean = 10, sd = 2))
  )

  if (has_elev) {
    posteriors$b_elev <- rnorm(n_draws, mean = -0.005, sd = 0.001)
  }

  if (has_sp) {
    posteriors$gp_ls <- abs(rnorm(n_draws, mean = 20, sd = 5))
    posteriors$gp_sigma <- abs(rnorm(n_draws, mean = 5, sd = 1))

    # Add spatial effects for 120 knots
    for (i in 1:120) {
      posteriors[[paste0("gp_effect_", i)]] <- rnorm(n_draws, mean = 0, sd = 3)
    }
  }

  # Create metadata
  metadata <- list(
    model_name = model_name,
    n_parameters = ncol(posteriors),
    n_draws = n_draws,
    has_elevation = has_elev,
    has_gp = has_sp,
    parameters = names(posteriors),
    created = Sys.Date()
  )

  # Save files
  posterior_file <- file.path(output_dir, "posteriors", paste0(model_name, "_posteriors.rds"))
  saveRDS(posteriors, posterior_file, compress = "xz", version = 2)
  cat("  - Saved posteriors:", format(file.info(posterior_file)$size, big.mark = ","), "bytes\n")

  metadata_file <- file.path(output_dir, "metadata", paste0(model_name, "_metadata.rds"))
  saveRDS(metadata, metadata_file, compress = "xz", version = 2)
  cat("  - Saved metadata:", format(file.info(metadata_file)$size, big.mark = ","), "bytes\n")

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

  # Create simplified lookup table for spatial models
  if (has_sp) {
    cat("  - Creating simplified lookup table\n")

    # Small grid for demonstration (10x10 degree)
    lon_seq <- seq(-180, 170, by = 10)
    lat_seq <- seq(-80, 80, by = 10)
    grid <- expand.grid(longitude = lon_seq, latitude = lat_seq)
    grid$cell_id <- 1:nrow(grid)

    # Simple spatial effects matrix
    spatial_effects <- matrix(
      rnorm(nrow(grid) * 100, mean = 0, sd = 3),
      nrow = nrow(grid),
      ncol = 100
    )

    lookup_table <- list(
      model_name = model_name,
      grid = grid,
      spatial_effects = spatial_effects,
      n_draws = 100,
      metadata = list(
        created = Sys.Date(),
        resolution = 10,
        bounds = list(
          lon = range(grid$longitude),
          lat = range(grid$latitude)
        )
      )
    )

    lookup_file <- file.path(output_dir, "lookup_tables", paste0(model_name, "_lookup.rds"))
    saveRDS(lookup_table, lookup_file, compress = "xz", version = 2)
    cat("  - Saved lookup table:", format(file.info(lookup_file)$size, big.mark = ","), "bytes\n")

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

# Summary
total_size <- sum(sapply(manifest$files, function(x) x$size))
cat("==========================================\n")
cat("Summary:\n")
cat("  Total files:", length(manifest$files), "\n")
cat("  Total size:", format(total_size, big.mark = ","), "bytes\n")
cat("  Total size:", round(total_size / 1024^2, 1), "MB\n")
cat("\nFiles prepared in:", output_dir, "\n")
cat("Manifest saved to:", manifest_file, "\n")