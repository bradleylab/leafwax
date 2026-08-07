# Download model data from the configured public release

Downloads model posterior draws from the release configured in
`inst/extdata/data_urls.json`. Development builds fail closed while
`release_ready` is false, preventing an older incompatible posterior
deposit from being mixed with the current package.

## Usage

``` r
download_model_data(
  model_name,
  version = "latest",
  data_type = c("posteriors"),
  cache_dir = NULL,
  overwrite = FALSE,
  verify = TRUE,
  verbose = TRUE
)
```

## Arguments

- model_name:

  Character string specifying the model name

- version:

  Version tag to download (default "latest")

- data_type:

  Type of data to download (only "posteriors" is currently supported)

- cache_dir:

  Directory to save files (default uses get_cache_dir())

- overwrite:

  Logical whether to overwrite existing files

- verify:

  Logical whether to verify file integrity with checksums

- verbose:

  Logical whether to show progress messages

## Value

Logical indicating success

## Examples
