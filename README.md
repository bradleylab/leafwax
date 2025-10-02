# leafwax

<!-- badges: start -->
[![R-CMD-check](https://github.com/yourusername/leafwax/workflows/R-CMD-check/badge.svg)](https://github.com/yourusername/leafwax/actions)
[![CRAN status](https://www.r-pkg.org/badges/version/leafwax)](https://CRAN.R-project.org/package=leafwax)
<!-- badges: end -->

## Overview

The **leafwax** package provides tools for Bayesian calibration and inversion of leaf wax hydrogen isotope measurements (δ²H) to reconstruct precipitation isotope values. It implements hierarchical Bayesian models that properly account for multiple sources of uncertainty including measurement error, biological fractionation, and spatial correlation.

## Key Features

- 🌍 **14 calibration models** with varying complexity and data requirements
- 📊 **Hierarchical Bayesian framework** for proper uncertainty propagation
- 🗺️ **Spatial Gaussian processes** using 125 Fibonacci sphere knots
- 📈 **Support for multiple covariates**: elevation, vegetation type, C4 percentage
- 🔧 **Automated model selection** based on available data
- 📦 **Efficient data management** with optional download of full posteriors

## Installation

You can install the development version of leafwax from GitHub:

```r
# install.packages("devtools")
devtools::install_github("yourusername/leafwax")
```

The package will be submitted to CRAN soon. Once available, you can install it with:

```r
install.packages("leafwax")
```

## Quick Start

```r
library(leafwax)

# Simple single-location inversion
result <- invert_d2h(
  d2h_wax = -150,           # Leaf wax δ²H value (‰)
  d2h_wax_err = 3,          # Measurement uncertainty (‰)
  longitude = -120,         # Longitude (decimal degrees)
  latitude = 40,            # Latitude (decimal degrees)
  model = "baseline"        # Model selection
)

# View results
print(result)
#>   d2h_precip_mean d2h_precip_sd d2h_precip_lower d2h_precip_upper
#> 1            10.4           4.1               3.7              17.1

# Multi-location inversion with spatial model
locations <- data.frame(
  d2h_wax = c(-150, -180, -120),
  longitude = c(-120, -100, -90),
  latitude = c(40, 35, 45)
)

result_spatial <- invert_d2h(
  d2h_wax = locations$d2h_wax,
  longitude = locations$longitude,
  latitude = locations$latitude,
  model = "baseline_sp"    # Spatial model
)
```

## Available Models

The package includes 14 calibration models with different capabilities:

| Model | Description | Spatial | Elevation | Vegetation |
|-------|-------------|---------|-----------|------------|
| `baseline` | Basic OIPC model | ❌ | ❌ | ❌ |
| `baseline_sp` | Basic with spatial GP | ✅ | ❌ | ❌ |
| `baseline_env` | With elevation effects | ❌ | ✅ | ❌ |
| `baseline_env_sp` | Elevation + spatial | ✅ | ✅ | ❌ |
| `baseline_veg` | With vegetation (PFT) | ❌ | ❌ | ✅ |
| `baseline_veg_sp` | Vegetation + spatial | ✅ | ❌ | ✅ |
| `c4_only_sp` | C4 effects only | ✅ | ❌ | C4 |
| `elevation_only_sp` | Elevation only | ✅ | ✅ | ❌ |
| `elevation_c4_sp` | Elevation + C4 | ✅ | ✅ | C4 |
| `elevation_c4_interact_sp` | With interactions | ✅ | ✅ | C4 |
| `full` | All effects | ❌ | ✅ | ✅ |
| `full_sp` | All + spatial | ✅ | ✅ | ✅ |
| `full_interact` | All + interactions | ❌ | ✅ | ✅ |
| `full_interact_sp` | Full model | ✅ | ✅ | ✅ |

Models with `_sp` suffix use spatial Gaussian processes for improved uncertainty quantification.

## Model Selection

Use the automated model selection to find the best model for your data:

```r
# Get model recommendations
recommendations <- get_model_recommendations(
  has_elevation = TRUE,     # You have elevation data
  has_c4 = FALSE,          # No C4 vegetation data
  prefer_spatial = TRUE    # Prefer spatial models
)

# Use the top recommended model
best_model <- names(recommendations)[1]
print(best_model)
#> [1] "baseline_env_sp"

# Validate your inputs for a specific model
validation <- validate_model_inputs(
  model_name = "baseline_env_sp",
  d2h_wax = -150,
  longitude = -120,
  latitude = 40,
  elevation = 1200
)
#> ✓ All inputs valid for model: baseline_env_sp
```

## Example with Uncertainty Visualization

```r
library(ggplot2)

# Perform inversion with full posterior
result <- invert_d2h(
  d2h_wax = seq(-200, -100, by = 20),
  longitude = rep(-120, 6),
  latitude = seq(30, 50, by = 4),
  model = "baseline_sp",
  return_full = FALSE
)

# Visualize results with uncertainty
ggplot(result, aes(x = d2h_wax, y = d2h_precip_mean)) +
  geom_ribbon(aes(ymin = d2h_precip_lower,
                  ymax = d2h_precip_upper),
              alpha = 0.3, fill = "blue") +
  geom_point(size = 3) +
  geom_errorbar(aes(ymin = d2h_precip_mean - d2h_precip_sd,
                    ymax = d2h_precip_mean + d2h_precip_sd),
                width = 2) +
  labs(x = "Leaf wax δ²H (‰)",
       y = "Precipitation δ²H (‰)",
       title = "Leaf Wax Isotope Inversion",
       subtitle = "Shaded area shows 90% credible interval") +
  theme_minimal()
```

## Citation

If you use this package in your research, please cite:

```
@software{leafwax2024,
  title = {leafwax: Bayesian Calibration of Leaf Wax Hydrogen Isotope Reconstructions},
  author = {Your Name},
  year = {2024},
  url = {https://github.com/yourusername/leafwax}
}
```

And cite the underlying methodological papers:

- Bowen, G. J., et al. (2019). Isotopes in the water cycle: Regional-to global-scale patterns and applications. *Annual Review of Earth and Planetary Sciences*, 47, 453-479.
- Sachse, D., et al. (2012). Molecular paleohydrology: Interpreting the hydrogen-isotopic composition of lipid biomarkers from photosynthesizing organisms. *Annual Review of Earth and Planetary Sciences*, 40, 221-249.

## Getting Help

- **Documentation**: Full documentation is available at [package website]
- **Vignettes**: See `vignette("getting-started", package = "leafwax")`
- **Issues**: Report bugs at [GitHub Issues](https://github.com/yourusername/leafwax/issues)

## Contributing

Contributions are welcome! Please read our [Contributing Guide](CONTRIBUTING.md) for details on our code of conduct and the process for submitting pull requests.

## License

This package is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.