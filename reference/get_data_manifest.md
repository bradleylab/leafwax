# Get data manifest

Loads or downloads the data manifest with file checksums. Returns `NULL`
with a warning when no current manifest is available. Download callers
that request verification fail closed in that case.

## Usage

``` r
get_data_manifest(cache_dir = NULL)
```

## Arguments

- cache_dir:

  Cache directory containing `manifest.json`.

## Value

Parsed manifest list, or `NULL` if no manifest is available locally and
the download failed.
