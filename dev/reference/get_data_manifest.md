# Get data manifest

Loads or downloads the data manifest with file checksums. Returns `NULL`
(with a [`warning()`](https://rdrr.io/r/base/warning.html)) when the
manifest is unreachable and there is no cached copy on disk; callers
must treat that as "checksum verification skipped" rather than "no
checksums found".

## Usage

``` r
get_data_manifest()
```

## Value

Parsed manifest list, or `NULL` if no manifest is available locally and
the download failed.
