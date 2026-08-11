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
# \donttest{
local({
  old <- options(leafwax.cache_dir = file.path(tempdir(), "leafwax_cache"))
  on.exit({
    unlink(getOption("leafwax.cache_dir"), recursive = TRUE, force = TRUE)
    options(old)
  })

  post_dir <- file.path(getOption("leafwax.cache_dir"), "posteriors")
  dir.create(post_dir, recursive = TRUE, showWarnings = FALSE)
  file.create(file.path(post_dir, "baseline_sp_posterior.rds"))

  # Clear cache for a specific model without prompting
  suppressMessages(clear_download_cache("baseline_sp", confirm = FALSE))
})
# }
```
