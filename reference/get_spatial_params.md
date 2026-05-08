# Get spatial parameters from lookup table

Retrieves pre-computed spatial parameters for given coordinates using
nearest neighbor or bilinear interpolation.

## Usage

``` r
get_spatial_params(
  longitude,
  latitude,
  lookup_table,
  method = c("nearest", "bilinear"),
  return_draws = TRUE
)
```

## Arguments

- longitude:

  Numeric vector of longitudes

- latitude:

  Numeric vector of latitudes

- lookup_table:

  Lookup table created by create_lookup_table()

- method:

  Interpolation method ("nearest" or "bilinear")

- return_draws:

  Logical whether to return all draws or just summary

## Value

Matrix of spatial effects (locations x draws) or summary statistics

## Examples

``` r
if (FALSE) { # \dontrun{
lookup <- create_lookup_table("b0b1_sp")
effects <- get_spatial_params(c(-120, -100), c(40, 35), lookup)
} # }
```
