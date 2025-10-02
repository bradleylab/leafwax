# prepare_package_data.R
# Script to create lightweight datasets for CRAN package distribution
# Run this script to regenerate the data/ directory contents

library(leafwax)
set.seed(42)  # For reproducibility

# Create data/ directory if it doesn't exist
if (!dir.exists("../data")) {
  dir.create("../data")
}

# ============================================================================
# 1. Create example input data
# ============================================================================

# Create a small example dataset with 10 locations
example_data <- data.frame(
  site_id = paste0("SITE_", 1:10),
  longitude = c(-120.5, -115.2, -110.8, -105.3, -100.1,
                -95.7, -90.2, -85.5, -80.1, -75.3),
  latitude = c(45.2, 42.8, 40.1, 38.5, 36.2,
               34.8, 32.5, 30.1, 28.7, 26.3),
  elevation = c(1200, 1500, 800, 1000, 500,
                300, 150, 50, 100, 25),
  d2h_wax = c(-145, -138, -152, -130, -125,
              -118, -112, -108, -105, -98),
  d2h_wax_sd = rep(3, 10),
  c4_fraction = c(0.1, 0.2, 0.15, 0.3, 0.4,
                  0.5, 0.6, 0.7, 0.65, 0.8),
  pft_tree = c(0.7, 0.6, 0.5, 0.4, 0.3,
               0.2, 0.1, 0.1, 0.2, 0.1),
  pft_shrub = c(0.2, 0.3, 0.3, 0.3, 0.3,
                0.3, 0.2, 0.2, 0.1, 0.1),
  pft_grass = c(0.1, 0.1, 0.2, 0.3, 0.4,
                0.5, 0.7, 0.7, 0.7, 0.8),
  stringsAsFactors = FALSE
)

# Add some metadata
attr(example_data, "description") <- "Example leaf wax d2H data from 10 sites"
attr(example_data, "source") <- "Simulated data for package examples"

# Save example data
save(example_data, file = "../data/example_data.rda", compress = "xz")
cat("Created example_data.rda\n")

# ============================================================================
# 2. Create model metadata
# ============================================================================

# Define all model configurations
model_metadata <- list(
  # Base models
  b0b1 = list(
    name = "b0b1",
    description = "Base model with intercept and slope",
    has_elevation = FALSE,
    has_c4 = FALSE,
    has_pft = FALSE,
    has_gp = FALSE,
    parameters = c("b0", "b1", "sigma"),
    n_parameters = 3,
    formula = "d2H_precip ~ b0 + b1 * d2H_wax"
  ),

  b0b1_elev = list(
    name = "b0b1_elev",
    description = "Base model with elevation effect",
    has_elevation = TRUE,
    has_c4 = FALSE,
    has_pft = FALSE,
    has_gp = FALSE,
    parameters = c("b0", "b1", "b_elev", "sigma"),
    n_parameters = 4,
    formula = "d2H_precip ~ b0 + b1 * d2H_wax + b_elev * elevation"
  ),

  b0b1_c4 = list(
    name = "b0b1_c4",
    description = "Base model with C4 vegetation effect",
    has_elevation = FALSE,
    has_c4 = TRUE,
    has_pft = FALSE,
    has_gp = FALSE,
    parameters = c("b0", "b1", "b_c4", "sigma"),
    n_parameters = 4,
    formula = "d2H_precip ~ b0 + b1 * d2H_wax + b_c4 * c4_fraction"
  ),

  b0b1_pft = list(
    name = "b0b1_pft",
    description = "Base model with plant functional types",
    has_elevation = FALSE,
    has_c4 = FALSE,
    has_pft = TRUE,
    has_gp = FALSE,
    parameters = c("b0", "b1", "b_tree", "b_shrub", "b_grass", "sigma"),
    n_parameters = 6,
    formula = "d2H_precip ~ b0 + b1 * d2H_wax + PFT_effects"
  ),

  # Spatial models
  b0b1_sp = list(
    name = "b0b1_sp",
    description = "Base model with spatial Gaussian process",
    has_elevation = FALSE,
    has_c4 = FALSE,
    has_pft = FALSE,
    has_gp = TRUE,
    parameters = c("b0", "b1", "sigma", "ls_gp", "sigma_gp", "z_spatial"),
    n_parameters = 125,  # 5 fixed + 120 spatial knots
    n_gp_knots = 120,
    formula = "d2H_precip ~ b0 + b1 * d2H_wax + GP(lon, lat)"
  ),

  b0b1_elev_sp = list(
    name = "b0b1_elev_sp",
    description = "Elevation model with spatial GP",
    has_elevation = TRUE,
    has_c4 = FALSE,
    has_pft = FALSE,
    has_gp = TRUE,
    parameters = c("b0", "b1", "b_elev", "sigma", "ls_gp", "sigma_gp", "z_spatial"),
    n_parameters = 126,
    n_gp_knots = 120,
    formula = "d2H_precip ~ b0 + b1 * d2H_wax + b_elev * elevation + GP(lon, lat)"
  ),

  b0b1_c4_sp = list(
    name = "b0b1_c4_sp",
    description = "C4 model with spatial GP",
    has_elevation = FALSE,
    has_c4 = TRUE,
    has_pft = FALSE,
    has_gp = TRUE,
    parameters = c("b0", "b1", "b_c4", "sigma", "ls_gp", "sigma_gp", "z_spatial"),
    n_parameters = 126,
    n_gp_knots = 120,
    formula = "d2H_precip ~ b0 + b1 * d2H_wax + b_c4 * c4_fraction + GP(lon, lat)"
  ),

  b0b1_pft_sp = list(
    name = "b0b1_pft_sp",
    description = "PFT model with spatial GP",
    has_elevation = FALSE,
    has_c4 = FALSE,
    has_pft = TRUE,
    has_gp = TRUE,
    parameters = c("b0", "b1", "b_tree", "b_shrub", "b_grass", "sigma",
                   "ls_gp", "sigma_gp", "z_spatial"),
    n_parameters = 128,
    n_gp_knots = 120,
    formula = "d2H_precip ~ b0 + b1 * d2H_wax + PFT_effects + GP(lon, lat)"
  ),

  # Combined models
  b0b1_elev_c4 = list(
    name = "b0b1_elev_c4",
    description = "Combined elevation and C4 model",
    has_elevation = TRUE,
    has_c4 = TRUE,
    has_pft = FALSE,
    has_gp = FALSE,
    parameters = c("b0", "b1", "b_elev", "b_c4", "sigma"),
    n_parameters = 5,
    formula = "d2H_precip ~ b0 + b1 * d2H_wax + b_elev * elevation + b_c4 * c4_fraction"
  ),

  b0b1_elev_pft = list(
    name = "b0b1_elev_pft",
    description = "Combined elevation and PFT model",
    has_elevation = TRUE,
    has_c4 = FALSE,
    has_pft = TRUE,
    has_gp = FALSE,
    parameters = c("b0", "b1", "b_elev", "b_tree", "b_shrub", "b_grass", "sigma"),
    n_parameters = 7,
    formula = "d2H_precip ~ b0 + b1 * d2H_wax + b_elev * elevation + PFT_effects"
  ),

  b0b1_c4_pft = list(
    name = "b0b1_c4_pft",
    description = "Combined C4 and PFT model",
    has_elevation = FALSE,
    has_c4 = TRUE,
    has_pft = TRUE,
    has_gp = FALSE,
    parameters = c("b0", "b1", "b_c4", "b_tree", "b_shrub", "b_grass", "sigma"),
    n_parameters = 7,
    formula = "d2H_precip ~ b0 + b1 * d2H_wax + b_c4 * c4_fraction + PFT_effects"
  ),

  # Full combined spatial models
  b0b1_elev_c4_sp = list(
    name = "b0b1_elev_c4_sp",
    description = "Full model with elevation, C4, and spatial GP",
    has_elevation = TRUE,
    has_c4 = TRUE,
    has_pft = FALSE,
    has_gp = TRUE,
    parameters = c("b0", "b1", "b_elev", "b_c4", "sigma",
                   "ls_gp", "sigma_gp", "z_spatial"),
    n_parameters = 127,
    n_gp_knots = 120,
    formula = "d2H_precip ~ b0 + b1 * d2H_wax + b_elev * elevation + b_c4 * c4_fraction + GP(lon, lat)"
  ),

  b0b1_elev_pft_sp = list(
    name = "b0b1_elev_pft_sp",
    description = "Full model with elevation, PFT, and spatial GP",
    has_elevation = TRUE,
    has_c4 = FALSE,
    has_pft = TRUE,
    has_gp = TRUE,
    parameters = c("b0", "b1", "b_elev", "b_tree", "b_shrub", "b_grass",
                   "sigma", "ls_gp", "sigma_gp", "z_spatial"),
    n_parameters = 129,
    n_gp_knots = 120,
    formula = "d2H_precip ~ b0 + b1 * d2H_wax + b_elev * elevation + PFT_effects + GP(lon, lat)"
  ),

  b0b1_elev_c4_pft_sp = list(
    name = "b0b1_elev_c4_pft_sp",
    description = "Full model with all covariates and spatial GP",
    has_elevation = TRUE,
    has_c4 = TRUE,
    has_pft = TRUE,
    has_gp = TRUE,
    parameters = c("b0", "b1", "b_elev", "b_c4", "b_tree", "b_shrub", "b_grass",
                   "sigma", "ls_gp", "sigma_gp", "z_spatial"),
    n_parameters = 130,
    n_gp_knots = 120,
    formula = "d2H_precip ~ b0 + b1 * d2H_wax + b_elev * elevation + b_c4 * c4_fraction + PFT_effects + GP(lon, lat)"
  )
)

# Add class
class(model_metadata) <- c("leafwax_model_metadata", "list")

# Save model metadata
save(model_metadata, file = "../data/model_metadata.rda", compress = "xz")
cat("Created model_metadata.rda\n")

# ============================================================================
# 3. Create a mini lookup table for examples
# ============================================================================

# Create a small 5x5 degree grid for demonstration
mini_grid <- expand.grid(
  lon = seq(-120, -80, by = 10),
  lat = seq(25, 45, by = 5)
)
mini_grid$cell_id <- seq_len(nrow(mini_grid))
mini_grid$lon_idx <- match(mini_grid$lon, unique(mini_grid$lon))
mini_grid$lat_idx <- match(mini_grid$lat, unique(mini_grid$lat))

# Create synthetic spatial effects (25 locations x 50 draws)
n_locations <- nrow(mini_grid)
n_draws <- 50

# Generate smooth spatial field using distance-based correlation
dist_matrix <- as.matrix(dist(mini_grid[, c("lon", "lat")]))
correlation_matrix <- exp(-dist_matrix / 20)  # Length scale of 20 degrees

# Generate correlated spatial effects
spatial_effects <- matrix(NA, nrow = n_locations, ncol = n_draws)
for (i in 1:n_draws) {
  # Generate correlated random field
  z <- rnorm(n_locations)
  spatial_effects[, i] <- as.vector(t(chol(correlation_matrix)) %*% z) * 5
}

# Create mini lookup table
mini_lookup_table <- list(
  model_name = "b0b1_sp_demo",
  grid = mini_grid,
  spatial_effects = spatial_effects,
  n_draws = n_draws,
  metadata = list(
    created = Sys.Date(),
    resolution = 10,
    bounds = list(
      lon = range(mini_grid$lon),
      lat = range(mini_grid$lat)
    ),
    gp_params = list(
      ls_mean = 20,
      ls_sd = 5,
      sigma_mean = 5,
      sigma_sd = 1
    ),
    description = "Demonstration lookup table with synthetic data"
  )
)

class(mini_lookup_table) <- c("leafwax_lookup_table", "list")

# Save mini lookup table
save(mini_lookup_table, file = "../data/mini_lookup_table.rda", compress = "xz")
cat("Created mini_lookup_table.rda\n")

# ============================================================================
# 4. Create minimal posterior draws for b0b1 model
# ============================================================================

# Create synthetic posterior draws for the simplest model
# This allows basic functionality without large files

# Generate synthetic posterior draws (100 draws for 3 parameters)
mini_posteriors_b0b1 <- data.frame(
  b0 = rnorm(100, mean = 20, sd = 5),
  b1 = rnorm(100, mean = 0.8, sd = 0.05),
  sigma = abs(rnorm(100, mean = 10, sd = 2))
)

# Create metadata for this model
mini_metadata_b0b1 <- list(
  model_name = "b0b1",
  has_elevation = FALSE,
  has_c4 = FALSE,
  has_pft = FALSE,
  has_gp = FALSE,
  parameters = c("b0", "b1", "sigma"),
  n_iterations = 100,
  n_chains = 1,
  description = "Minimal synthetic posteriors for package examples"
)

# Combine into a posterior object
mini_posteriors <- list(
  b0b1 = list(
    draws = mini_posteriors_b0b1,
    metadata = mini_metadata_b0b1
  )
)

# Save minimal posteriors
save(mini_posteriors, file = "../data/mini_posteriors.rda", compress = "xz")
cat("Created mini_posteriors.rda\n")

# ============================================================================
# 5. Check file sizes
# ============================================================================

cat("\n=== File Sizes ===\n")
data_files <- list.files("../data", full.names = TRUE)
for (file in data_files) {
  size_kb <- file.info(file)$size / 1024
  cat(sprintf("%s: %.1f KB\n", basename(file), size_kb))
}

total_size <- sum(file.info(data_files)$size) / 1024
cat(sprintf("\nTotal size: %.1f KB\n", total_size))

if (total_size > 1024) {
  cat(sprintf("Warning: Total size %.1f MB may be large for CRAN\n", total_size / 1024))
} else {
  cat("Size is appropriate for CRAN submission\n")
}

cat("\n=== Data preparation complete ===\n")