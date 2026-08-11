# Bayesian inversion of a linear calibration posterior

Integrates a proper prior with a normal likelihood for paired posterior
draws of the intercept, slope, and residual standard deviation. This
avoids unstable division by slopes near zero and preserves
calibration-draw pairing.

## Usage

``` r
bayesian_linear_inverse(
  y,
  intercept,
  slope,
  residual_sd,
  analytical_sd = 0,
  prior,
  credible_level = 0.9,
  grid_size = 2001L,
  integration_tolerance = 0.001,
  tail_mass_tolerance = 1e-08,
  max_refinements = 4L,
  n_samples = 0L,
  seed = NULL
)
```

## Arguments

- y:

  Observed response value.

- intercept, slope, residual_sd:

  Paired calibration posterior draws.

- analytical_sd:

  Known response-space analytical standard deviation.

- prior:

  A proper prior created by one of the `d2h_prior_*()` functions.

- credible_level:

  Probability in the central credible interval.

- grid_size:

  Odd number of grid points used for numerical integration.

- integration_tolerance:

  Maximum permitted change in reported summaries between nested
  numerical grids, in precipitation-isotope units.

- tail_mass_tolerance:

  Maximum permitted posterior mass in either outer grid cell for an
  unbounded prior.

- max_refinements:

  Maximum domain-expansion attempts.

- n_samples:

  Number of optional posterior samples to return.

- seed:

  Required integer seed when `n_samples` is positive.

## Value

A `leafwax_inverse_grid` object containing the normalized posterior,
summaries, numerical and identifiability diagnostics, and optional
samples.
