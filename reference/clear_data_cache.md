# Clear model data cache

Removes cached model data files to free up disk space.

## Usage

``` r
clear_data_cache(model_name = NULL, data_type = NULL, confirm = TRUE)
```

## Arguments

- model_name:

  Model to clear (NULL for all)

- data_type:

  Type of data to clear (NULL for all)

- confirm:

  Logical, whether to ask for confirmation

## Value

Logical indicating success

## Examples

``` r
if (FALSE) { # \dontrun{
# Clear cache for specific model
clear_data_cache("b0b1_sp")

# Clear all full datasets
clear_data_cache(data_type = "full")
} # }
```
