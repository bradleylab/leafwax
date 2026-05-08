# Local effective slope at a paleo-reconstruction site

Returns a per-draw vector of the d2H_wax-d2H_precip slope at a single
site, combining the global posterior beta_oipc with the spatial slope GP
prediction at that site. The result is the quantity a paleohydrologist
needs in Section 4.5.5 of the manuscript: a site-specific slope
posterior with an explicit upper bound from simple-model fractionation
theory.

## Usage

``` r
local_effective_slope(
  longitude,
  latitude,
  model_name,
  override = NULL,
  ceiling = 0.88,
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
  [`available_models()`](https://bradleylab.github.io/leafwax/reference/available_models.md)).
  Must be a spatial model (`*_sp`) for the site-specific slope to differ
  from the global mean; non-spatial models return the global posterior
  unchanged.

- override:

  Optional numeric. NULL (default) uses the model slope. A single value
  broadcasts across all draws. A vector of length `n_draws` is used per
  draw.

- ceiling:

  Optional numeric upper bound on the slope. Default `0.88`, the
  simple-model ceiling under stationarity. Set to `Inf` or `NULL` to
  disable.

- n_draws:

  Integer, optional number of posterior draws to use (`NULL` uses all).
  Forwarded to
  [`load_posteriors()`](https://bradleylab.github.io/leafwax/reference/load_posteriors.md).

- verbose:

  Logical, whether to print progress messages.

## Value

Numeric vector of length `n_draws`, the per-draw effective slope at the
site (after override and ceiling, in that order).

## Details

Three modes:

- Default: returns the model's per-draw slope at the site.

- Override (single value or per-draw vector) replaces the model slope
  with a defended local value (e.g., from independent evidence about
  source-water seasonality, leaf-water enrichment, or vegetation).

- Ceiling: any draw exceeding `ceiling` (default 0.88, the simple-model
  upper bound from `epsilon_app ~= -120 permil`) is truncated to the
  ceiling. A warning is emitted when more than 5\\ the user's intended
  interpretation are inconsistent with the simple-model bound.

Pass the returned vector to `invert_d2H(..., slope = ...)` to propagate
it through the inversion.

## Examples

``` r
# \donttest{
# St. Louis with the baseline_sp model
s <- local_effective_slope(
  longitude = -90, latitude = 38,
  model_name = "baseline_sp",
  n_draws = 200
)
summary(s)
#>    Min. 1st Qu.  Median    Mean 3rd Qu.    Max. 
#>  0.3503  0.5562  0.6124  0.6189  0.6793  0.8733 

# Override with a defended local slope
s_fixed <- local_effective_slope(
  longitude = -90, latitude = 38,
  model_name = "baseline_sp",
  override = 0.55, ceiling = 0.88
)

# Pass through to the inversion. The slope vector and the
# inversion's posterior must use the same n_draws: pair
# local_effective_slope(..., n_draws = N) with
# invert_d2H(..., n_posterior_draws = N, slope = s), or pass a
# single point estimate (e.g., median(s)).
invert_d2H(d2H_wax = -180, d2H_wax_sd = 3,
           longitude = -90, latitude = 38,
           model_name = "baseline_sp",
           n_posterior_draws = 200,
           slope = s)
#> Loading model: baseline_sp 
#> Loading model: baseline_sp 
#>   Loaded 1000 draws, 271 parameters
#>   Subsampled to 200 draws (deterministic stratified)
#>   Loaded 125 spatial knots
#>   Loaded standardization parameters (20 fields)
#> Performing inversion for 1 locations
#>   Computing dual-GP spatial effects (Matern 3/2)...
#>   Using slope override (range: 0.350 to 0.873) instead of the model's site-specific slope.
#> Computing predictions...
#> 
#> Inversion complete:
#>   Mean prediction range: [-58.5, -58.5] per mil
#>   Mean uncertainty (SD): 6.7 per mil
#>   Mean 90% CI width: 21.6 per mil
#>   longitude latitude elevation d2h_wax d2h_wax_err d2h_precip_mean
#> 1       -90       38         0    -180           3       -58.46658
#>   d2h_precip_median d2h_precip_sd d2h_precip_lower d2h_precip_upper
#> 1         -58.51641      6.678374        -69.79661        -48.16367
#>   prediction_interval_width
#> 1                  21.63295
# }
```
