# Estimate lag-1 temporal autocorrelation

Estimate the lag-1 autocorrelation `rho_t` of a leaf-wax record's
residuals after a flat-mean detrend, ordering by age. This is the
quantity that enters the within-record detection threshold from
manuscript Section 4.5.3 (`Var(X1 - X2) = 2 sigma^2 (1 - rho_t)`).

## Usage

``` r
estimate_temporal_autocorrelation(
  d2h_wax,
  age,
  method = c("ar1", "lomb_scargle")
)
```

## Arguments

- d2h_wax:

  Numeric vector of leaf-wax delta-2-H measurements (per mil).

- age:

  Numeric vector of sample ages, same length as `d2h_wax`.

- method:

  One of `"ar1"` or `"lomb_scargle"`.

## Value

Numeric scalar in `[-1, 1]`, or `NA_real_` when the residuals are
constant (e.g., n \< 3 finite samples).

## Details

Two methods are supported:

- `"ar1"` (default): Pearson correlation of `resid[-n]` with `resid[-1]`
  after age-ordering. For irregularly sampled series this is an
  approximation; see `"lomb_scargle"` for an alternative.

- `"lomb_scargle"`: not yet implemented. Returns an error pointing the
  user at `"ar1"` until the spectral implementation lands. The plan is
  to estimate `rho_t` from the dominant timescale of a Lomb-Scargle
  periodogram on the irregularly sampled series.

## Examples

``` r
# \donttest{
set.seed(1)
n <- 200
rho <- 0.7
e  <- numeric(n); e[1] <- rnorm(1, 0, 5)
for (k in 2:n) e[k] <- rho * e[k-1] + rnorm(1, 0, 5 * sqrt(1 - rho^2))
ag <- seq(0, 10000, length.out = n)
estimate_temporal_autocorrelation(-150 + e, ag)
#> [1] 0.6923911
# }
```
