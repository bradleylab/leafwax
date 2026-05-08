# Use lookup table in inversion (if available)

Checks if a lookup table is available for the model and uses it for
faster spatial parameter computation.

## Usage

``` r
use_lookup_if_available(
  model_name,
  longitude,
  latitude,
  cache_dir = NULL,
  method = "bilinear"
)
```

## Arguments

- model_name:

  Name of the model

- longitude:

  Longitude coordinates

- latitude:

  Latitude coordinates

- cache_dir:

  Directory where lookup tables are cached

- method:

  Interpolation method for lookup ("nearest" or "bilinear")

## Value

List with spatial parameters or NULL if no lookup table
