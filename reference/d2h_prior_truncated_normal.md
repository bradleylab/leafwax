# Truncated-normal prior for precipitation-isotope inversion

Truncated-normal prior for precipitation-isotope inversion

## Usage

``` r
d2h_prior_truncated_normal(mean, sd, lower, upper, units = "permil VSMOW")
```

## Arguments

- mean:

  Mean of the untruncated normal distribution.

- sd:

  Positive standard deviation of the untruncated normal distribution.

- lower, upper:

  Finite prior bounds with `lower < upper`.

- units:

  Label for the isotope units.

## Value

A proper prior specification for Bayesian inversion.
