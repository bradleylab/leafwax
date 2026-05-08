# Within-record d2H_precip change detection

Given a downcore
[`invert_d2H()`](https://bradleylab.github.io/leafwax/reference/invert_d2h.md)
reconstruction posterior with full draws (`return_full = TRUE`), report
(a) the posterior probability that the difference in mean `d2H_precip`
between two stratigraphic intervals exceeds user-supplied magnitudes,
and (b) the within- record 95\\ 4.5.3:

## Usage

``` r
detect_change(
  reconstruction,
  age,
  baseline_interval,
  test_intervals = NULL,
  sigma_within,
  sigma_analytical = 3,
  rho_t = NULL,
  beta_eff,
  confidence = 0.95,
  magnitudes = NULL
)
```

## Arguments

- reconstruction:

  Output of `invert_d2H(..., return_full = TRUE)` on a downcore series.
  Must contain a `posterior_draws` matrix of shape `n_iter x n_samples`.

- age:

  Numeric vector, length `n_samples`, of sample ages matching the
  reconstruction columns.

- baseline_interval:

  Length-2 numeric `c(min, max)` defining the baseline window in `age`
  units.

- test_intervals:

  Either a length-2 numeric vector for a single test window, or a named
  list of length-2 numerics for multiple windows. NULL skips the
  per-interval probability table and returns only the threshold.

- sigma_within:

  Numeric, required, the within-record residual SD in leaf-wax per mil
  (typically from
  [`estimate_sigma_within()`](https://bradleylab.github.io/leafwax/reference/estimate_sigma_within.md)).

- sigma_analytical:

  Numeric, the analytical uncertainty on `d2H_wax` measurements in per
  mil (default 3).

- rho_t:

  Numeric, lag-1 temporal autocorrelation. Use
  [`estimate_temporal_autocorrelation()`](https://bradleylab.github.io/leafwax/reference/estimate_temporal_autocorrelation.md)
  to compute. Defaults to 0 (independent samples) with a message.

- beta_eff:

  Numeric, the local effective slope. Use
  [`local_effective_slope()`](https://bradleylab.github.io/leafwax/reference/local_effective_slope.md)
  for a point estimate (e.g., its median).

- confidence:

  Numeric in (0, 1), the confidence level for the detection threshold.
  Default 0.95.

- magnitudes:

  Optional numeric vector of magnitudes (per mil) to evaluate posterior
  `Pr(|delta| > magnitude)` against.

## Value

A list with elements:

- `threshold` - the detection threshold on `d2H_precip` at the requested
  confidence level.

- `formula` - the components used: `z`, `rho_t`, `sigma_within`,
  `sigma_analytical`, `beta_eff`.

- `intervals` - a data frame with one row per test interval reporting
  the posterior median and CI of `delta` and (if `magnitudes` supplied)
  the posterior probability of exceeding each magnitude.

## Details

\$\$\mathrm{threshold}\_{precip} = \frac{z\_{\alpha/2}\\ \sqrt{2(1 -
\rho_t)}\\ \sqrt{\sigma\_{within}^2 + \sigma\_{analytical}^2}}
{\beta\_{\mathrm{eff}}}\$\$

The threshold is the smallest difference in `d2H_precip` between two
independent samples that can be distinguished from within-record noise
at the chosen confidence level.
