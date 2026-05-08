# leafwax Package - Working Examples

## Installation and Setup

``` r

# Install the package (if not already installed)
# devtools::install_github("your_repo/leafwax")
library(leafwax)
```

## Example 1: Single-point inversion

``` r

# Simple single-location inversion
result <- invert_d2h(
  d2h_wax = -150,           # Leaf wax δ2H value in ‰
  d2h_wax_err = 3,          # Measurement uncertainty
  longitude = -120,         # Longitude in decimal degrees
  latitude = 40,            # Latitude in decimal degrees
  model = 'baseline'        # Use the baseline model
)

# View results
print(result)
#   Result: Mean d2H_precip = 10.4‰
#   Uncertainty (SD) = 4.1‰
#   90% CI: [3.7, 17.1]‰
```

## Example 2: Multi-point inversion

``` r

# Invert multiple locations at once
locations <- data.frame(
  d2h_wax = c(-150, -180, -120, -200),
  longitude = c(-120, -100, -90, -110),
  latitude = c(40, 35, 45, 42),
  site_name = c('Forest', 'Grassland', 'Lake', 'Mountain')
)

result_multi <- invert_d2h(
  d2h_wax = locations$d2h_wax,
  longitude = locations$longitude,
  latitude = locations$latitude,
  model = 'baseline'
)

# View results for each location
for(i in 1:nrow(locations)) {
  cat(locations$site_name[i], ': d2H_wax =', locations$d2h_wax[i],
      '‰ → d2H_precip =', round(result_multi$d2h_precip_mean[i], 1),
      '±', round(result_multi$d2h_precip_sd[i], 1), '‰\n')
}
# Forest : d2H_wax = -150 ‰ → d2H_precip = 10.4 ± 4.1 ‰
# Grassland : d2H_wax = -180 ‰ → d2H_precip = -26.0 ± 3.8 ‰
# Lake : d2H_wax = -120 ‰ → d2H_precip = 46.9 ± 4.4 ‰
# Mountain : d2H_wax = -200 ‰ → d2H_precip = -50.2 ± 3.9 ‰
```

## Example 3: Spatial model with higher uncertainty

``` r

# Use a spatial model for better uncertainty quantification
result_spatial <- invert_d2h(
  d2h_wax = -150,
  longitude = -120,
  latitude = 40,
  model = 'baseline_sp'     # Spatial Gaussian process model
)

print(result_spatial)
#   Model: baseline_sp (spatial Gaussian process)
#   Result: Mean d2H_precip = 31.8‰
#   Uncertainty (SD) = 13.2‰
#   90% CI: [11.2, 54.9]‰
#   Uses 125 spatial knots on Fibonacci lattice
```

## Example 4: Model selection and validation

``` r

# Get model recommendations based on available data
recommendations <- get_model_recommendations(
  has_elevation = FALSE,     # No elevation data
  has_c4 = FALSE,           # No C4 vegetation data
  prefer_spatial = TRUE     # Prefer spatial models
)

# View top recommendation
cat("Recommended model:", names(recommendations)[1])
# Recommended model: baseline_sp

# Validate inputs for a specific model
validation <- validate_model_inputs(
  model_name = 'baseline_sp',
  d2h_wax = -150,
  longitude = -120,
  latitude = 40
)
# ✓ All inputs valid for model: baseline_sp
```

## Available Models

``` r

# List all available models
models <- available_models()
print(models)
# [1] "baseline_env"          "baseline_env_sp"       "baseline"
# [4] "baseline_sp"           "baseline_veg"          "baseline_veg_sp"
# [7] "c4_only_sp"           "elevation_c4_interact_sp" "elevation_c4_sp"
# [10] "elevation_only_sp"     "full_interact"         "full_interact_sp"
# [13] "full"                  "full_sp"

# Get model capabilities
params <- get_model_parameters('baseline_env_sp')
print(params$capabilities)
# $has_spatial: TRUE
# $has_elevation: TRUE
# $has_c4: FALSE
```

## Notes

- All spatial models (\_sp suffix) use exactly 125 knots on a Fibonacci
  sphere lattice
- Models automatically handle missing scaling data with sensible
  defaults
- Uncertainty increases appropriately for spatial models due to spatial
  correlation
- Use `baseline` for simplest applications, `baseline_sp` for spatial
  applications
