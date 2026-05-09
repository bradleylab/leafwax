# Load posterior draws for a model

Loads posterior draws for one of the 14 leafwax v10 models. The function
searches three tiers in order:

## Usage

``` r
load_posteriors(model_name, n_draws = NULL, verbose = TRUE)
```

## Arguments

- model_name:

  Character string specifying the model name.

- n_draws:

  Integer number of posterior draws to use, or `NULL` for all available.
  Requesting more draws than are present silently returns whatever is
  available (e.g. all 100 from the preview tier).

- verbose:

  Logical indicating whether to print loading info.

## Value

A `leafwax_posterior` object: a list with `draws`, `metadata` (including
`metadata$tier`, one of "heavy", "cache", "light"), optional `spatial`,
and accessor closures.

## Details

1.  **Heavy** posteriors at `inst/extdata/posteriors/` (1000 draws,
    development install only; excluded from the CRAN tarball).

2.  **Cache** populated by
    [`download_model_data()`](https://bradleylab.github.io/leafwax/reference/download_model_data.md)
    under
    [`get_cache_dir()`](https://bradleylab.github.io/leafwax/reference/get_cache_dir.md).

3.  **Preview** posteriors at `inst/extdata/posteriors_light/`. These
    are a 100-draw stratified subsample shipped with every install so
    examples and tests run offline. They are intended as a fixture for
    code-path verification, **not** for inference: tail probabilities
    and 95% credible intervals are noisy at this sample size. The
    package issues a warning whenever the preview tier is in use;
    downstream functions
    ([`invert_d2H()`](https://bradleylab.github.io/leafwax/reference/invert_d2h.md),
    [`assess_claim()`](https://bradleylab.github.io/leafwax/reference/assess_claim.md),
    [`detect_change()`](https://bradleylab.github.io/leafwax/reference/detect_change.md))
    repeat the warning so it is visible at the call that actually
    matters.

For inference, run
[`download_model_data()`](https://bradleylab.github.io/leafwax/reference/download_model_data.md)
once to populate the cache and then call `load_posteriors()` again – the
cache tier wins over the preview tier and no further downloads are
needed.

## Examples

``` r
# Load a model (preview tier on a fresh install)
model <- load_posteriors("baseline")
#> Loading model: baseline
#>   Loaded 100 draws, 17 parameters
#> Warning: leafwax preview posteriors in use: 100 draws of 'baseline'. Tail probabilities and 95% credible intervals are unstable at this sample size; not suitable for inference. Run download_model_data("baseline") for the full posterior.
#>   Loaded standardization parameters (20 fields)

# Spatial model with limited draws
model_fast <- load_posteriors("baseline_sp", n_draws = 50)
#> Loading model: baseline_sp
#>   Loaded 100 draws, 271 parameters
#>   Subsampled to 50 draws (deterministic stratified)
#> Warning: leafwax preview posteriors in use: 50 draws of 'baseline_sp'. Tail probabilities and 95% credible intervals are unstable at this sample size; not suitable for inference. Run download_model_data("baseline_sp") for the full posterior.
#>   Loaded 125 spatial knots
#>   Loaded standardization parameters (20 fields)
```
