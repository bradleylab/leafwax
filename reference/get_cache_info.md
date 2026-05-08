# Get cache size information

Reports the disk space used by cached model data.

## Usage

``` r
get_cache_info(by_model = FALSE, by_type = FALSE)
```

## Arguments

- by_model:

  Logical, whether to break down by model

- by_type:

  Logical, whether to break down by data type

## Value

Data frame with cache size information

## Examples

``` r
if (FALSE) { # \dontrun{
# Get total cache size
cache_info <- get_cache_info()

# Get size by model and type
cache_info <- get_cache_info(by_model = TRUE, by_type = TRUE)
} # }
```
