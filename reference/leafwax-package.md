# leafwax: Bayesian Calibration of Leaf Wax Hydrogen Isotope Reconstructions

The leafwax package provides tools for probabilistic inversion of leaf
wax hydrogen isotope measurements (delta-2-H) to reconstruct
precipitation isotope values. It implements hierarchical Bayesian models
that account for multiple sources of uncertainty including measurement
error, biological fractionation, and spatial correlation in isotope
patterns.

## Main Functions

- [`invert_d2H`](https://bradleylab.github.io/leafwax/reference/invert_d2h.md):

  Bayesian inversion of leaf wax delta2H to precipitation delta2H

- [`available_models`](https://bradleylab.github.io/leafwax/reference/available_models.md):

  List all available calibration models

- [`load_posteriors`](https://bradleylab.github.io/leafwax/reference/load_posteriors.md):

  Load posterior distributions for a specific model

- [`get_model_parameters`](https://bradleylab.github.io/leafwax/reference/get_model_parameters.md):

  Get model capabilities and required parameters

- [`validate_model_inputs`](https://bradleylab.github.io/leafwax/reference/validate_model_inputs.md):

  Validate inputs for a specific model

## Available Models

The package includes 14 calibration models with different capabilities.
The v10 fits include precipitation amount (`baseline_env*` and `full*`
variants), C4 abundance, and PFT cover; none of the v10 variants carry a
fitted elevation coefficient despite the historical "elevation\_\*"
naming. Runtime capability flags in
[`load_posteriors()`](https://bradleylab.github.io/leafwax/reference/load_posteriors.md)
are derived from each model's posterior columns at load time.

- **Basic models**: baseline, baseline_sp

- **Precipitation models**: baseline_env, baseline_env_sp

- **Vegetation models**: baseline_veg, baseline_veg_sp, c4_only_sp

- **Combined spatial models**: elevation_only_sp, elevation_c4_sp,
  elevation_c4_interact_sp

- **Full models**: full, full_sp, full_interact, full_interact_sp

Models with "\_sp" suffix use spatial Gaussian processes with 125 knots
on a Fibonacci sphere lattice for improved uncertainty quantification.

## Model Selection

Pass `model = "auto"` to
[`predict_d2h_precip()`](https://bradleylab.github.io/leafwax/reference/predict_d2h_precip.md)
to let
[`select_best_model_from_flags()`](https://bradleylab.github.io/leafwax/reference/select_best_model_from_flags.md)
choose a model based on which covariates the caller has supplied;
otherwise pick a model name from
[`available_models()`](https://bradleylab.github.io/leafwax/reference/available_models.md)
explicitly.

## Key Features

- Hierarchical Bayesian framework for uncertainty propagation

- Support for single and multi-location inversions

- Spatial correlation via Gaussian processes

- Automatic handling of missing covariates

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

Bradley, A. (2026). leafwax v10 model posteriors. Zenodo DOI
[doi:10.5281/zenodo.20085465](https://doi.org/10.5281/zenodo.20085465) .

## See also

Useful links:

- <https://github.com/bradleylab/leafwax>

- <https://bradleylab.github.io/leafwax/>

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
result <- invert_d2H(
  d2H_wax = -150,
  d2H_wax_sd = 3,
  longitude = -120,
  latitude = 40,
  model_name = "baseline"
)
#> Loading model: baseline 
#> Loading model: baseline
#>   Loaded 100 draws, 17 parameters
#>   Loaded standardization parameters (20 fields)
#> Performing inversion for 1 locations
#> Computing predictions...
#> 
#> Inversion complete:
#>   Mean prediction range: [-33.3, -33.3] per mil
#>   Mean uncertainty (SD): 26.8 per mil
#>   Mean 90% width: 90.2 per mil
#> Warning: leafwax preview posteriors in use (invert_d2H): 100 draws of 'baseline'. Tail probabilities and 95% credible intervals are unstable at this sample size; not suitable for inference. Run download_model_data("baseline") for the full posterior.
```
