# Check if model data exists in cache

Checks whether the heavy posterior file for a model is present in the
user cache populated by
[`download_model_data()`](https://bradleylab.github.io/leafwax/reference/download_model_data.md).

## Usage

``` r
check_data_cache(
  model_name,
  data_type = c("minimal", "standard", "full"),
  verbose = FALSE
)
```

## Arguments

- model_name:

  Character string specifying the model name.

- data_type:

  Retained for API compatibility. The v0.2 download layout ships a
  single posterior file per model (`posteriors/<model>_posterior.rds`)
  so all values check the same path; the argument is accepted but
  otherwise ignored.

- verbose:

  Logical, whether to print status messages.

## Value

Logical indicating whether the cached posterior file exists.

## Examples

``` r
if (FALSE) { # \dontrun{
exists <- check_data_cache("baseline_sp")
} # }
```
