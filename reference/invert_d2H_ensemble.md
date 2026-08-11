# Ensemble predictions across multiple models

Runs
[`invert_d2H`](https://bradleylab.github.io/leafwax/reference/invert_d2h.md)
against each model in `models` and combines the per-draw reconstructions
per site, preserving the per-site dimension. Useful for downstream
uncertainty estimates that should span structural model uncertainty
rather than condition on one calibration variant.

## Usage

``` r
invert_d2H_ensemble(..., models = NULL, ensemble_method = c("equal", "all"))
```

## Arguments

- ...:

  Arguments passed to
  [`invert_d2H`](https://bradleylab.github.io/leafwax/reference/invert_d2h.md)
  (e.g., `d2H_wax`, `d2H_wax_sd`, `longitude`, `latitude`, optional
  covariates).

- models:

  Explicit character vector of compatible Bayesian-inversion model
  names. There is no scientific default ensemble.

- ensemble_method:

  `"equal"` (default) pools per-draw reconstructions per site across
  models with equal weighting and returns a per-site posterior. `"all"`
  returns the per-model results without pooling.

## Value

If `ensemble_method = "equal"`, a list with: `posterior_draws` (an
`n_draws x n_sites` matrix of pooled per-site, per-draw
reconstructions), `ensemble_summary` (a data frame with one row per
site: `mean`, `median`, `sd`, `ci_90_lower`/`ci_90_upper`,
`ci_95_lower`/`ci_95_upper`, `n_models_used`), `model_results` (the
per-model output from
[`invert_d2H()`](https://bradleylab.github.io/leafwax/reference/invert_d2h.md)
with `return_full = TRUE`), `models_used` (the models actually pooled),
and `ensemble_method`. If `ensemble_method = "all"`, only
`model_results` and `ensemble_method` are returned.
