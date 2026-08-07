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

1.  **Heavy** posteriors at `inst/extdata/posteriors/` (complete
    retained draws in a validated development checkout; excluded from
    the tarball).

2.  **Cache** populated by a validated public data release under
    [`get_cache_dir()`](https://bradleylab.github.io/leafwax/dev/reference/get_cache_dir.md).

3.  **Preview** posteriors at `inst/extdata/posteriors_light/`. These
    are a 100-draw stratified subsample shipped with every install so
    examples and tests run offline. They are intended as a fixture for
    code-path verification, **not** for inference: tail probabilities
    and 95% credible intervals are noisy at this sample size. The
    package warns when this tier is loaded, and inferential functions
    fail closed.

Public download wiring is disabled in the current development build
until the coordinated chordal data release passes final validation. For
current inference, use a validated working checkout containing the
complete posterior deposit.

## Examples

``` r
local({
  old <- options(leafwax.suppress_preview_warning = TRUE)
  on.exit(options(old))

  # Load a model (preview tier on a fresh install)
  model <- load_posteriors("baseline", verbose = FALSE)

  # Spatial model with limited draws
  model_fast <- load_posteriors("baseline_sp", n_draws = 50, verbose = FALSE)
})
```
