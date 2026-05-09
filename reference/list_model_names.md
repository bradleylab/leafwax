# List model names

Returns the names of every model the package can resolve. Prefers the
heavy posteriors directory when present (development install), otherwise
falls back to the lightweight posteriors directory that ships with every
install. The user cache is intentionally not enumerated here so the
answer is stable regardless of what has been downloaded.

## Usage

``` r
list_model_names()
```

## Value

Character vector of model names. Empty if neither directory contains
posterior files.
