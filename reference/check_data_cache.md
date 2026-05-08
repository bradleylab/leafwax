# Check if model data exists in cache

Checks whether the specified model data files exist in the local cache.

## Usage

``` r
check_data_cache(
  model_name,
  data_type = c("minimal", "standard", "full"),
  verbose = FALSE
)
```

## Arguments

- model_name:

  Character string specifying the model name

- data_type:

  Type of data to check: "minimal", "standard", or "full"

- verbose:

  Logical, whether to print status messages

## Value

Logical indicating whether the data exists

## Examples

``` r
if (FALSE) { # \dontrun{
# Check if standard data exists for a model
exists <- check_data_cache("b0b1_sp", "standard")
} # }
```
