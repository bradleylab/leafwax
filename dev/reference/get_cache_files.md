# Get cache files for a model

Internal helper that returns the cached file paths for a model. The v0.2
download layout ships a single posterior per model at
`posteriors/<model>_posterior.rds`, so the returned vector has at most
one element. The `data_type` argument is accepted for API compatibility
but does not affect the result.

## Usage

``` r
get_cache_files(model_name, data_type, cache_dir)
```

## Arguments

- model_name:

  Model name.

- data_type:

  Retained for API compatibility (ignored).

- cache_dir:

  Cache directory path.

## Value

Character vector of cached file paths that exist on disk.
