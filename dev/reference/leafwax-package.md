# leafwax: Bayesian Calibration of Leaf Wax Hydrogen Isotope Reconstructions

The leafwax package provides tools for probabilistic inversion of leaf
wax hydrogen isotope measurements (delta-2-H) to reconstruct
precipitation isotope values. It integrates an explicit proper
reconstruction prior with the likelihood under paired draws from frozen
hierarchical calibration posteriors.

## Main Functions

- [`invert_d2H`](https://bradleylab.github.io/leafwax/dev/reference/invert_d2h.md):

  Bayesian inversion of leaf wax delta2H to precipitation delta2H

- [`available_models`](https://bradleylab.github.io/leafwax/dev/reference/available_models.md):

  List all available calibration models

- [`load_posteriors`](https://bradleylab.github.io/leafwax/dev/reference/load_posteriors.md):

  Load posterior distributions for a specific model

- [`get_model_parameters`](https://bradleylab.github.io/leafwax/dev/reference/get_model_parameters.md):

  Get model capabilities and required parameters

- [`validate_model_inputs`](https://bradleylab.github.io/leafwax/dev/reference/validate_model_inputs.md):

  Validate inputs for a specific model

## Available Models

The package can inspect 14 calibration models with different
capabilities. The v10 fits include precipitation amount (`baseline_env*`
and `full*` variants), C4 abundance, and PFT cover; none of the v10
variants carry a fitted elevation coefficient despite the historical
"elevation\_\*" naming. Runtime capability flags in
[`load_posteriors()`](https://bradleylab.github.io/leafwax/dev/reference/load_posteriors.md)
are derived from each model's posterior columns at load time. The
validated inversion interface currently supports only `baseline`,
`baseline_sp`, and `c4_only_sp`; other designs fail closed because their
complete new-site predictor basis is unavailable.

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
[`predict_d2h_precip()`](https://bradleylab.github.io/leafwax/dev/reference/predict_d2h_precip.md)
to choose between the supported spatial baseline and C4-only designs.
Model ensembles have no scientific default and must be supplied
explicitly.

## Key Features

- Explicit proper reconstruction priors

- Joint multi-row calibration-draw reweighting

- Spatial correlation via Gaussian processes

- No slope division, clipping, or post-hoc draw removal

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

- <https://bradleylab.github.io/leafwax/>

- Report bugs at <https://github.com/bradleylab/leafwax/issues>

## Author

**Maintainer**: Alexander S. Bradley <abradley@wustl.edu>
([ORCID](https://orcid.org/0000-0002-4044-2802))

## Examples

``` r
  # List available models
  models <- available_models()
  n_models <- length(models)

  # Priors are explicit; this constructor does not run an inversion.
  prior <- d2h_prior_normal(mean = -70, sd = 30)
```
