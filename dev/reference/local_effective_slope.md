# Local effective slope at a paleo-reconstruction site

Returns a per-draw vector of the local \\\beta\_{\delta^2 H_p}\\
calibration slope at a single site, combining the global
precipitation-isotope slope with the spatial slope GP prediction at that
site. The returned vector is the raw posterior at the site; every draw
the calibration produced is preserved without modification.

## Usage

``` r
local_effective_slope(
  longitude,
  latitude,
  model_name,
  override = NULL,
  n_draws = NULL,
  verbose = FALSE
)
```

## Arguments

- longitude:

  Numeric, single longitude in decimal degrees.

- latitude:

  Numeric, single latitude in decimal degrees.

- model_name:

  Character, v10 model name (see
  [`available_models()`](https://bradleylab.github.io/leafwax/dev/reference/available_models.md)).
  Must be a spatial model (`*_sp`) for the site-specific slope to differ
  from the global mean; non-spatial models return the global posterior
  unchanged.

- override:

  Optional numeric. NULL (default) uses the model slope. A single value
  broadcasts across all draws. A vector of length `n_draws` is used per
  draw.

- n_draws:

  Integer, optional number of posterior draws to use (`NULL` uses all).
  Forwarded to
  [`load_posteriors()`](https://bradleylab.github.io/leafwax/dev/reference/load_posteriors.md).

- verbose:

  Logical, whether to print progress messages.

## Value

Numeric vector of length `n_draws`, the per-draw effective slope at the
site (after override, if any).

## Details

Two modes:

- Default: returns the model's per-draw slope at the site.

- Override (single value or per-draw vector) replaces the model slope
  with a defended local value (e.g., from independent evidence about
  source-water seasonality, leaf-water enrichment, or vegetation).

The Bayesian inversion propagates its paired local-slope draws
internally. Pass this vector as `slope = ...` only when deliberately
overriding that internal calculation with a separately defended slope
posterior.

Mechanistic reference values (e.g. the simple two-pool stationarity
bound `alpha = 1 + epsilon_app/1000` ~ 0.88 under
`epsilon_app ~= -120 permil`; Sessions 2005) are documented for
interpretation but are never applied to the returned draws. The
frequency of draws above any chosen reference is computable directly
from the returned vector (`mean(slope > 0.88)`) and carries scientific
information about how often the calibration implicates non-stationarity
at the site.

## Examples

``` r
if (FALSE) { # \dontrun{
local({
  old <- options(leafwax.suppress_preview_warning = TRUE)
  on.exit(options(old))

  # St. Louis with the baseline_sp model
  s <- local_effective_slope(
    longitude = -90, latitude = 38,
    model_name = "baseline_sp",
    n_draws = 200
  )
  slope_summary <- summary(s)

  # How often does the calibration imply a slope above the simple-model
  # stationarity bound at this site?
  fraction_above_bound <- mean(s > 0.88)

  # Override with a defended local slope
  s_fixed <- local_effective_slope(
    longitude = -90, latitude = 38,
    model_name = "baseline_sp",
    override = 0.55
  )

  # Pass through to the inversion. The slope vector and the
  # inversion's posterior must use the same n_draws: pair
  # local_effective_slope(..., n_draws = N) with
  # invert_d2H(..., n_posterior_draws = N, slope = s), or pass a
  # single point estimate (e.g., median(s)).
  result <- invert_d2H(d2H_wax = -180, d2H_wax_sd = 3,
                       longitude = -90, latitude = 38,
                       model_name = "baseline_sp",
                       n_posterior_draws = 200,
                       slope = s,
                       prior = d2h_prior_normal(-70, 30),
                       verbose = FALSE)
})
} # }
```
