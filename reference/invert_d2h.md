# Bayesian inversion of leaf-wax d2H to precipitation d2H

Performs a likelihood-times-prior inversion over paired calibration
posterior draws. No division by a sampled slope, clipping, or post-hoc
draw removal is used. Multiple rows jointly reweight the shared
calibration draw.

## Usage

``` r
invert_d2H(
  d2H_wax,
  d2H_wax_sd = NULL,
  longitude,
  latitude,
  elevation = NULL,
  elevation_sd = 100,
  c4_fraction = NULL,
  c4_fraction_sd = 10,
  pft_tree = NULL,
  pft_shrub = NULL,
  pft_grass = NULL,
  model_name = "baseline",
  n_posterior_draws = NULL,
  return_full = FALSE,
  credible_level = 0.9,
  verbose = TRUE,
  record_id = NULL,
  slope = NULL,
  prior = NULL,
  n_inverse_samples = 0L,
  seed = NULL,
  grid_size = 2001L,
  integration_tolerance = 0.001,
  tail_mass_tolerance = 1e-08,
  draw_stability_tolerance = 2
)

invert_d2h(
  d2h_wax,
  d2h_wax_err = NULL,
  longitude,
  latitude,
  elevation = NULL,
  c4_percent = NULL,
  pft_tree = NULL,
  pft_shrub = NULL,
  pft_grass = NULL,
  model_name = "baseline",
  n_draws = NULL,
  return_full = FALSE,
  credible_level = 0.9,
  verbose = TRUE,
  record_id = NULL,
  slope = NULL,
  prior = NULL,
  n_inverse_samples = 0L,
  seed = NULL,
  grid_size = 2001L,
  integration_tolerance = 0.001,
  tail_mass_tolerance = 1e-08,
  draw_stability_tolerance = 2
)
```

## Arguments

- d2H_wax:

  Numeric vector of leaf wax d2H values (per mil)

- d2H_wax_sd:

  Numeric vector of measurement uncertainties (per mil)

- longitude, latitude:

  Numeric site coordinates in decimal degrees.

- elevation:

  Optional elevations retained in the output but not consumed by the
  currently supported inversion designs.

- elevation_sd:

  Elevation uncertainty (not used, kept for compatibility)

- c4_fraction:

  Numeric vector of C4 vegetation cover as a fraction in `[0, 1]`. The
  wrapper converts to the percent (0-100) scale used internally before
  standardisation.

- c4_fraction_sd:

  C4 fraction uncertainty (not used, kept for compatibility)

- pft_tree, pft_shrub, pft_grass:

  Unsupported PFT inputs; supplying any currently fails closed.

- model_name:

  One of `baseline`, `baseline_sp`, or `c4_only_sp`.

- n_posterior_draws:

  Integer number of posterior draws to use

- return_full:

  Whether to return joint posterior samples.

- credible_level:

  Central credible interval probability.

- verbose:

  Whether to report loading and diagnostic status.

- record_id:

  Identifier for a single shared-site record. Optional for a one-row
  inversion and required when `length(d2h_wax) > 1`.

- slope:

  Optional scalar or paired-draw override in per mil wax per per mil
  precipitation. It is converted to the fitted model's standardized
  coefficient internally. Zero and negative values are retained.

- prior:

  Required proper precipitation-isotope prior from a `d2h_prior_*()`
  constructor, or one prior per row.

- n_inverse_samples:

  Number of joint inverse-posterior samples. Required to be positive
  when `return_full = TRUE`; otherwise it must be zero.

- seed:

  Explicit integer seed required for inverse-posterior samples.

- grid_size:

  Numerical integration grid size.

- integration_tolerance:

  Maximum permitted nested-grid summary change.

- tail_mass_tolerance:

  Maximum permitted unbounded-prior edge mass.

- draw_stability_tolerance:

  Maximum permitted summary change when the paired calibration draw bank
  is reduced to a deterministic nested half.

- d2h_wax:

  Numeric vector of observed leaf-wax isotope values in per mil.

- d2h_wax_err:

  Non-negative analytical standard deviations in per mil.

- c4_percent:

  C4 cover on a 0–100 scale, required by `c4_only_sp`.

- n_draws:

  Optional deterministic thinning count for paired calibration posterior
  draws.

## Value

A `leafwax_inverse` object. Its `status` is `"inconclusive"` if
numerical or saved-draw stability tolerances fail. Posterior samples are
present only when explicitly requested with a seed.
