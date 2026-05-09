# Get data download URLs

Constructs download URLs for model data from GitHub releases.

## Usage

``` r
get_data_url(model_name, version = "latest", data_type = c("posteriors"))
```

## Arguments

- model_name:

  Character string specifying the model name

- version:

  Version tag (e.g., "v1.0.0" or "latest")

- data_type:

  Type of data (only "posteriors" is currently supported)

## Value

List of download URLs and filenames

## Examples

``` r
if (FALSE) { # \dontrun{
# Get URLs for latest version
urls <- get_data_url("baseline_sp", "latest")

# Get URLs for specific version
urls <- get_data_url("baseline_sp", "v1.0.1")
} # }
```
