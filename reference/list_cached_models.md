# List available models in cache

Lists all models that have been downloaded to the local cache.

## Usage

``` r
list_cached_models(data_type = NULL, verbose = TRUE)
```

## Arguments

- data_type:

  Filter by data type (NULL for any)

- verbose:

  Logical, whether to print detailed information

## Value

Character vector of available model names

## Examples

``` r
if (FALSE) { # \dontrun{
# List all cached models
models <- list_cached_models()

# List models with full data
models_full <- list_cached_models(data_type = "full")
} # }
```
