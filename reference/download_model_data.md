# Download model data from GitHub releases

Downloads model posterior draws and lookup tables from GitHub releases
with progress tracking and integrity verification.

## Usage

``` r
download_model_data(
  model_name,
  version = "latest",
  data_type = c("both", "posteriors", "lookup"),
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

  Type of data to download: "posteriors", "lookup", or "both"

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

``` r
if (FALSE) { # \dontrun{
# Download latest data for a model
download_model_data("b0b1_sp", version = "latest")

# Download specific version
download_model_data("b0b1_elev", version = "v1.0.0")
} # }
```
