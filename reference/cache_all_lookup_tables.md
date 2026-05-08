# Cache all lookup tables for available spatial models

Pre-computes and caches lookup tables for all spatial models in the
package. This is useful for deployment or when you want to pre-generate
all tables.

## Usage

``` r
cache_all_lookup_tables(
  cache_dir,
  n_draws = 100,
  models = NULL,
  verbose = TRUE
)
```

## Arguments

- cache_dir:

  Directory to save cached lookup tables

- n_draws:

  Number of posterior draws to use for each model

- models:

  Character vector of model names (NULL for all spatial models)

- verbose:

  Logical indicating whether to print progress

## Value

Invisible NULL

## Examples

``` r
if (FALSE) { # \dontrun{
cache_all_lookup_tables("~/leafwax_cache", n_draws = 100)
} # }
```
