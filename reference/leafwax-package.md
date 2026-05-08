# leafwax: Bayesian Calibration of Leaf Wax Hydrogen Isotope Reconstructions

The leafwax package provides tools for probabilistic inversion of leaf
wax hydrogen isotope measurements (δ2H) to reconstruct precipitation
isotope values. It implements hierarchical Bayesian models that account
for multiple sources of uncertainty including measurement error,
biological fractionation, and spatial correlation in isotope patterns.

## Main Functions

- [`invert_d2h`](https://bradleylab.github.io/leafwax/reference/invert_d2h.md):

  Perform Bayesian inversion of leaf wax δ2H to precipitation δ2H

- [`available_models`](https://bradleylab.github.io/leafwax/reference/available_models.md):

  List all available calibration models

- [`load_posteriors`](https://bradleylab.github.io/leafwax/reference/load_posteriors.md):

  Load posterior distributions for a specific model

- [`get_model_parameters`](https://bradleylab.github.io/leafwax/reference/get_model_parameters.md):

  Get model capabilities and required parameters

- [`validate_model_inputs`](https://bradleylab.github.io/leafwax/reference/validate_model_inputs.md):

  Validate inputs for a specific model

- [`get_model_recommendations`](https://bradleylab.github.io/leafwax/reference/get_model_recommendations.md):

  Get model recommendations based on available data

## Available Models

The package includes 14 calibration models with different capabilities:

- **Basic models**: baseline, baseline_sp

- **Elevation models**: baseline_env, baseline_env_sp, elevation_only_sp

- **Vegetation models**: baseline_veg, baseline_veg_sp, c4_only_sp

- **Combined models**: elevation_c4_sp, elevation_c4_interact_sp

- **Full models**: full, full_sp, full_interact, full_interact_sp

Models with "\_sp" suffix use spatial Gaussian processes with 125 knots
on a Fibonacci sphere lattice for improved uncertainty quantification.

## Model Selection

Choose models based on available ancillary data:

- Use `baseline` for simple applications with only location data

- Use `baseline_env` when elevation data is available

- Use `baseline_veg` when vegetation (PFT) data is available

- Use spatial models (\_sp) for better uncertainty quantification

- Use
  [`get_model_recommendations()`](https://bradleylab.github.io/leafwax/reference/get_model_recommendations.md)
  for automated model selection

## Key Features

- Hierarchical Bayesian framework for uncertainty propagation

- Support for single and multi-location inversions

- Spatial correlation via Gaussian processes

- Automatic handling of missing covariates

- Comprehensive model validation and recommendations

## References

Bowen, G. J., Cai, Z., Fiorella, R. P., & Putman, A. L. (2019). Isotopes
in the water cycle: Regional-to global-scale patterns and applications.
Annual Review of Earth and Planetary Sciences, 47, 453-479.
[doi:10.1146/annurev-earth-053018-060220](https://doi.org/10.1146/annurev-earth-053018-060220)

Sachse, D., Billault, I., Bowen, G. J., Chikaraishi, Y., Dawson, T. E.,
Feakins, S. J., ... & Kahmen, A. (2012). Molecular paleohydrology:
Interpreting the hydrogen-isotopic composition of lipid biomarkers from
photosynthesizing organisms. Annual Review of Earth and Planetary
Sciences, 40, 221-249.
[doi:10.1146/annurev-earth-042711-105535](https://doi.org/10.1146/annurev-earth-042711-105535)

## See also

Useful links:

- <https://github.com/bradleylab/leafwax>

- Report bugs at <https://github.com/bradleylab/leafwax/issues>

## Author

**Maintainer**: Alex Bradley <abradley@wustl.edu>
([ORCID](https://orcid.org/0000-0002-4044-2802))

## Examples

``` r
# List available models
models <- available_models()
print(models)
#>  [1] "baseline_env"             "baseline_env_sp"         
#>  [3] "baseline"                 "baseline_sp"             
#>  [5] "baseline_veg"             "baseline_veg_sp"         
#>  [7] "c4_only_sp"               "elevation_c4_interact_sp"
#>  [9] "elevation_c4_sp"          "elevation_only_sp"       
#> [11] "full_interact"            "full_interact_sp"        
#> [13] "full"                     "full_sp"                 

# Simple single-location inversion
result <- invert_d2h(
  d2h_wax = -150,
  longitude = -120,
  latitude = 40,
  model = "baseline"
)
#> Using default measurement uncertainty of 3 per mil
#> Loading model: baseline 
#> Loading model: baseline 
#>   Loaded 1000 draws, 17 parameters
#>   Loaded standardization parameters (20 fields)
#> Performing inversion for 1 locations
#> Computing predictions...
#> 
#> Inversion complete:
#>   Mean prediction range: [-34, -34] per mil
#>   Mean uncertainty (SD): 4.1 per mil
#>   Mean 90% CI width: 13.2 per mil

# Get model recommendations based on available data
recommendations <- get_model_recommendations(
  has_elevation = TRUE,
  prefer_spatial = TRUE
)
```
