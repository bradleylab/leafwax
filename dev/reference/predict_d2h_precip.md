# Predict precipitation d2H from leaf wax d2H

Main user-facing function for inverting leaf wax hydrogen isotopes to
precipitation isotopes. Automatically selects appropriate model based on
available data and returns results in a tidy format.

## Usage

``` r
predict_d2h_precip(
  data = NULL,
  d2h_wax = NULL,
  longitude = NULL,
  latitude = NULL,
  d2h_wax_err = NULL,
  elevation = NULL,
  c4_fraction = NULL,
  pft_tree = NULL,
  pft_shrub = NULL,
  pft_grass = NULL,
  record_id = NULL,
  model = "auto",
  n_draws = NULL,
  credible_level = 0.9,
  return_draws = FALSE,
  progress = TRUE,
  verbose = TRUE,
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

- data:

  Data frame containing measurements, or NULL to use individual vectors

- d2h_wax:

  Numeric vector of leaf wax d2H values (per mil)

- longitude:

  Numeric vector of longitudes (decimal degrees)

- latitude:

  Numeric vector of latitudes (decimal degrees)

- d2h_wax_err:

  Numeric vector of measurement uncertainties (optional)

- elevation:

  Numeric vector of elevations in meters (optional)

- c4_fraction:

  Numeric vector of C4 vegetation fraction 0-1 (optional)

- pft_tree:

  Numeric vector of tree PFT fraction (optional)

- pft_shrub:

  Numeric vector of shrub PFT fraction (optional)

- pft_grass:

  Numeric vector of grass PFT fraction (optional)

- record_id:

  Optional identifier for one same-site record; required for multi-row
  input.

- model:

  Character string specifying model, or "auto" for automatic selection

- n_draws:

  Integer number of posterior draws (NULL for all)

- credible_level:

  Numeric credible interval level (default 0.9)

- return_draws:

  Logical whether to return full posterior draws

- progress:

  Logical whether to show progress bar for batch processing

- verbose:

  Logical whether to print status messages

- prior:

  Required proper precipitation-isotope prior.

- n_inverse_samples:

  Number of joint posterior samples when `return_draws = TRUE`.

- seed:

  Explicit seed required when posterior samples are requested.

- grid_size, integration_tolerance, tail_mass_tolerance:

  Numerical integration controls passed to
  [`invert_d2H()`](https://bradleylab.github.io/leafwax/dev/reference/invert_d2h.md).

- draw_stability_tolerance:

  Saved-draw stability tolerance in per mil.

## Value

A `leafwax_inverse` object. Its `summary` data frame contains the
posterior median, central interval, and supporting moments for each row;
diagnostics and method metadata are always returned. Joint
`posterior_draws` are included only when `return_draws = TRUE` with an
explicit sample count and seed.

The interval is the posterior predictive specified in manuscript
Supplementary Note 8 (Section S8.1; analytical uncertainty plus the
model's posterior residual SD).

## Examples

``` r
if (FALSE) { # \dontrun{
local({
  old <- options(leafwax.suppress_preview_warning = TRUE)
  on.exit(options(old))

  # Using data frame input
  data(example_data)
  prior <- d2h_prior_normal(mean = -70, sd = 30)
  results <- predict_d2h_precip(
    example_data, prior = prior, verbose = FALSE
  )

  # Using individual vectors
  results <- predict_d2h_precip(
    d2h_wax = c(-150, -140, -130),
    longitude = rep(-90, 3),
    latitude = rep(38, 3),
    record_id = "example_record",
    elevation = c(1000, 1500, 500), prior = prior,
    verbose = FALSE
  )

  # Specify model explicitly
  results <- predict_d2h_precip(
    example_data,
    model = "baseline_sp", prior = prior,
    verbose = FALSE
  )

  # Get full posterior draws
  results <- predict_d2h_precip(
    example_data,
    prior = prior, return_draws = TRUE,
    n_inverse_samples = 1000, seed = 20260801,
    verbose = FALSE
  )
})
} # }
```
