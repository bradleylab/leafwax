# Verify data integrity

Verifies the integrity of downloaded files using checksums.

## Usage

``` r
verify_data_integrity(filepath, model_name = NULL, filename = NULL)
```

## Arguments

- filepath:

  Path to the file to verify

- model_name:

  Model name for looking up expected checksum

- filename:

  Filename for looking up expected checksum

## Value

Logical indicating whether the file is valid
