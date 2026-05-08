# Create lookup table for spatial parameters

Pre-computes spatial effects for each grid cell using a model's spatial
parameters (GP knots, length scale, variance).

## Usage

``` r
create_lookup_table(
  model_name,
  grid = NULL,
  n_draws = 100,
  cache_dir = NULL,
  verbose = TRUE
)
```

## Arguments

- model_name:

  Name of the model to create lookup table for

- grid:

  Data frame with lon/lat coordinates (default global 1x1 grid)

- n_draws:

  Number of posterior draws to use (NULL for all)

- cache_dir:

  Directory to save cached lookup tables (NULL for no caching)

- verbose:

  Logical indicating whether to print progress

## Value

List containing lookup table and metadata

## Examples

``` r
if (FALSE) { # \dontrun{
lookup <- create_lookup_table("b0b1_sp")
str(lookup)
} # }
```
