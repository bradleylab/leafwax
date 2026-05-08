# Matern 3/2 covariance: k(d) = sigma^2 \* (1 + sqrt(3)\*d/rho) \* exp(-sqrt(3)\*d/rho)

Matern 3/2 covariance: k(d) = sigma^2 \* (1 + sqrt(3)\*d/rho) \*
exp(-sqrt(3)\*d/rho)

## Usage

``` r
matern32(d, sigma, rho)
```

## Arguments

- d:

  numeric matrix or vector of Euclidean distances (in standardized
  units)

- sigma:

  marginal SD

- rho:

  length scale (in standardized units; SAME units as d)

## Value

covariance values matching shape of d
