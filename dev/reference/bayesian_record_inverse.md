# Joint Bayesian inversion of a multi-sample record

Each row has its own latent precipitation-isotope value and proper
prior, while all rows share and jointly reweight the paired calibration
draws.

## Usage

``` r
bayesian_record_inverse(
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
  n_samples,
  seed
)
```

## Arguments

- y:

  Numeric vector of observed response values.

- intercept, slope:

  Matrices with calibration draws in rows and observations in columns.

- residual_sd:

  Positive vector with one value per calibration draw.

- analytical_sd:

  Non-negative scalar or one value per observation.

- prior:

  A `leafwax_d2h_prior`, applied to every observation, or a list
  containing one such prior per observation.

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

  Number of joint posterior samples. Set to zero for a deterministic
  summary without samples.

- seed:

  Required integer seed when `n_samples` is positive.

## Value

A `leafwax_inverse` object with row summaries, diagnostics, marginal
grids, joint samples, and sampled calibration-draw identifiers.
