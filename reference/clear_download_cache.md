# Clear download cache

Removes downloaded model data from the local cache.

## Usage

``` r
clear_download_cache(
  model_name = NULL,
  type = c("all", "posteriors"),
  confirm = TRUE
)
```

## Arguments

- model_name:

  Model name to clear (NULL for all)

- type:

  Type of data to clear: "all" or "posteriors"

- confirm:

  Whether to ask for confirmation

## Value

Invisible NULL

## Examples

``` r
if (FALSE) { # \dontrun{
# Clear cache for specific model
clear_download_cache("baseline_sp")

# Clear all cached data
clear_download_cache(confirm = FALSE)
} # }
```
