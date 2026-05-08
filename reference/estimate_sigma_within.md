# Estimate the within-record residual SD of a leaf-wax record

Estimate a within-record residual standard deviation `sigma_within` from
a stratigraphic baseline interval of a downcore leaf-wax delta-2-H
record. Within-record residual variance is generally smaller than the
global posterior sigma, because spatial structure cancels and
between-site sources of variance (laboratory, vegetation background,
basin size, integration timescale) do not vary inside a single record.
Manuscript Section 4.5.3 explains why and frames the obligations on the
user.

## Usage

``` r
estimate_sigma_within(
  d2h_wax,
  age,
  baseline_interval = NULL,
  detrend = c("none", "linear", "loess"),
  ar1_correction = TRUE
)
```

## Arguments

- d2h_wax:

  Numeric vector of leaf-wax delta-2-H measurements (per mil).

- age:

  Numeric vector of sample ages (any monotone time-like variable; same
  length as `d2h_wax`).

- baseline_interval:

  Length-2 numeric `c(min, max)` defining the baseline window in `age`
  units. `NULL` means use the full record (warning emitted).

- detrend:

  One of `"none"` (default), `"linear"`, or `"loess"`, describing how to
  remove trends within the baseline before computing residuals.
  `"linear"` fits `lm(d2h_wax ~ age)`. `"loess"` fits
  `loess(d2h_wax ~ age, span = 0.75)`.

- ar1_correction:

  Logical (default `TRUE`); if `TRUE`, applies the AR(1) variance
  reduction described above.

## Value

A list with elements:

- `sigma_within` - point estimate (per mil), AR(1)-corrected if
  requested.

- `sigma_within_se` - asymptotic standard error of the returned
  `sigma_within`.

- `sigma_naive` - sample SD of residuals before AR(1) correction.

- `n_baseline` - number of samples used.

- `rho_t_baseline` - lag-1 temporal autocorrelation of residuals in the
  baseline.

- `method` - one-line description of the choices made.

## Details

The function operates on the baseline interval only. With
`baseline_interval = NULL`, the entire record is treated as the baseline
and a warning is emitted: this conflates real climate variability with
measurement and process noise, so the returned `sigma_within` is an
upper bound rather than a defended estimate. Real use should specify a
stratigraphic interval over which stationarity of vegetation, hydrology,
and source-water seasonality can be defended on independent grounds.

Within the baseline window, the function:

1.  subsets the record to the baseline,

2.  optionally detrends (`"linear"` or `"loess"`) to remove
    long-wavelength trends that the user does not want absorbed into the
    residual SD,

3.  computes the lag-1 temporal autocorrelation (`rho_t`) of the
    residuals,

4.  returns the naive standard deviation of the residuals
    (`sd(residuals)`) and an AR(1)-corrected effective SD when
    `ar1_correction = TRUE`. The correction is
    `sigma_eff = sigma_naive * sqrt(1 - rho_t^2)` for `|rho_t| < 1`, a
    conservative reduction that accounts for the variance sequential
    samples share.

The standard error of `sigma_within` is approximated by
`sigma_within / sqrt(2 * (n_baseline - 1))`, the asymptotic SE of a
normal-distribution sample SD.

## Examples

``` r
# \donttest{
# Synthetic stationary baseline: noise around a flat mean
set.seed(1)
n  <- 80
ag <- seq(0, 8000, length.out = n)
d  <- -160 + rnorm(n, 0, 5)
est <- estimate_sigma_within(d, ag,
                             baseline_interval = c(0, 4000),
                             detrend = "none",
                             ar1_correction = TRUE)
est$sigma_within
#> [1] 4.430219
# }
```
