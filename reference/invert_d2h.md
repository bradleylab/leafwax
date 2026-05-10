# Invert leaf wax d2H to precipitation d2H

Uses Bayesian posterior draws to invert leaf wax hydrogen isotope values
to precipitation isotope values, accounting for all fitted model
components including vegetation effects and spatial correlations where
applicable.

## Usage

``` r
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
  slope = NULL
)

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
  slope = NULL
)
```

## Arguments

- d2h_wax:

  Numeric vector of leaf wax d2H values (per mil)

- d2h_wax_err:

  Numeric vector of measurement uncertainties (per mil)

- longitude:

  Numeric vector of longitudes (decimal degrees)

- latitude:

  Numeric vector of latitudes (decimal degrees)

- elevation:

  Numeric vector of elevations (meters)

- c4_percent:

  Numeric vector of C4 vegetation percentage (0-100)

- pft_tree:

  Numeric vector of tree PFT fraction (0-1)

- pft_shrub:

  Numeric vector of shrub PFT fraction (0-1)

- pft_grass:

  Numeric vector of grass PFT fraction (0-1)

- model_name:

  Character string specifying which model to use

- n_draws:

  Integer number of posterior draws to use (NULL for all)

- return_full:

  Logical whether to return full posterior draws or just summary

- credible_level:

  Numeric credible interval level (default 0.9)

- verbose:

  Logical whether to print progress messages

- record_id:

  Character or numeric, optional record identifier. When supplied and
  constant across all input rows, all rows are treated as belonging to
  the same downcore series: the spatial Gaussian process is evaluated
  once per posterior draw at the shared site, so spatial draws are
  reused across the series rather than redrawn per row. The current
  implementation already shares spatial draws between identical
  (longitude, latitude) pairs; the `record_id` argument adds explicit
  validation that the caller intends within-record inference.

- slope:

  Optional numeric override for the d2H_wax-d2H_precip slope. NULL
  (default) uses the model's site-specific slope, i.e., `beta_oipc` plus
  the spatial slope GP perturbation at the site. A single numeric
  replaces the slope with a fixed point estimate (broadcast across all
  posterior draws). A vector of length `n_draws` is used per draw. Use
  [`local_effective_slope()`](https://bradleylab.github.io/leafwax/reference/local_effective_slope.md)
  to build a defensible per-draw override that respects the manuscript's
  simple-model ceiling at alpha = 0.88 (Section 4.5.5). When supplied,
  the override applies uniformly to every input row.

- d2H_wax:

  Numeric vector of leaf wax d2H values (per mil)

- d2H_wax_sd:

  Numeric vector of measurement uncertainties (per mil)

- elevation_sd:

  Elevation uncertainty (not used, kept for compatibility)

- c4_fraction:

  Numeric vector of C4 vegetation cover as a fraction in `[0, 1]`. The
  wrapper converts to the percent (0-100) scale used internally before
  standardisation.

- c4_fraction_sd:

  C4 fraction uncertainty (not used, kept for compatibility)

- n_posterior_draws:

  Integer number of posterior draws to use

## Value

If return_full is FALSE, a data frame with columns:

- d2h_precip_mean:

  Mean predicted precipitation d2H

- d2h_precip_median:

  Median predicted precipitation d2H

- d2h_precip_sd:

  Standard deviation of the posterior predictive interval

- d2h_precip_lower:

  Lower bound of the credible interval

- d2h_precip_upper:

  Upper bound of the credible interval

- prediction_interval_width:

  Width of the credible interval (upper - lower).

The interval is the posterior predictive specified in manuscript
supplement Section S4.1, Eq. 7: the wax-error draw combines analytical
uncertainty with the model's posterior residual SD `sigma`. For
within-record change detection, the spatial GP intercept's contribution
cancels in any contrast computed from the returned `posterior_draws`
(manuscript Section 4.5.3); the same `sigma` applies in both regimes.

If return_full is TRUE, a list with:

- summary:

  The summary data frame described above

- posterior_draws:

  Matrix of all posterior draws (n_draws x n_locations)

- model_info:

  Information about the model used.

## Examples

``` r
if (FALSE) { # \dontrun{
# Simple inversion with base model
results <- invert_d2h(
  d2h_wax = c(-150, -140, -130),
  d2h_wax_err = c(3, 3, 3),
  longitude = c(-120, -110, -100),
  latitude = c(40, 35, 30),
  elevation = c(1000, 1500, 500),
  model = "baseline"
)

# Inversion with spatial model
results <- invert_d2h(
  d2h_wax = c(-150, -140, -130),
  d2h_wax_err = c(3, 3, 3),
  longitude = c(-120, -110, -100),
  latitude = c(40, 35, 30),
  elevation = c(1000, 1500, 500),
  model = "baseline_sp",
  return_full = TRUE
)
} # }
```
