# Get data download URLs

Constructs download URLs for the configured model-data release.

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
urls <- get_data_url("baseline_sp", "latest")
} # }
```
