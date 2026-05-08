# Get list of files to download for a model

Internal function to determine which files need to be downloaded based
on model name and data type.

## Usage

``` r
get_download_files(model_name, data_type)
```

## Arguments

- model_name:

  Character string specifying the model name

- data_type:

  Type of data: "minimal", "standard", or "full"

## Value

List of file information
