# Create optimized lookup table for region

Creates a high-resolution lookup table for a specific region of
interest. This is useful when you need higher accuracy for a specific
area.

## Usage

``` r
create_regional_lookup(
  model_name,
  lon_range,
  lat_range,
  resolution = 0.5,
  n_draws = 100,
  cache_dir = NULL,
  verbose = TRUE
)
```

## Arguments

- model_name:

  Name of the model

- lon_range:

  Vector of length 2 with min and max longitude

- lat_range:

  Vector of length 2 with min and max latitude

- resolution:

  Grid resolution in degrees (default 0.5)

- n_draws:

  Number of posterior draws

- cache_dir:

  Directory to save the lookup table

- verbose:

  Logical indicating whether to print progress

## Value

Lookup table object

## Examples

``` r
if (FALSE) { # \dontrun{
# Create high-res lookup for Western US
lookup_west <- create_regional_lookup(
  "b0b1_sp",
  lon_range = c(-130, -100),
  lat_range = c(30, 50),
  resolution = 0.5
)
} # }
```
