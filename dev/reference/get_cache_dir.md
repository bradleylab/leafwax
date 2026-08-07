# Get leafwax data cache directory

Returns the path to the local cache directory for leafwax model data.
Uses rappdirs for platform-specific paths or a user-specified directory.

## Usage

``` r
get_cache_dir(create = TRUE)
```

## Arguments

- create:

  Logical, whether to create the directory if it doesn't exist

## Value

Character string with the cache directory path

## Examples

``` r
# \donttest{
local({
  old <- options(leafwax.cache_dir = file.path(tempdir(), "leafwax_cache"))
  on.exit(options(old))

  cache_dir <- get_cache_dir(create = FALSE)
  dir.exists(cache_dir)
})
#> [1] FALSE
# }
```
