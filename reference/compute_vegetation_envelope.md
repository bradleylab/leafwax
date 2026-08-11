# Vegetation-only envelope for a paleo wax-isotope record

Computes the posterior-propagated wax-shift envelope expected under a
user-supplied PFT-change scenario, holding `d2H_precip` constant. This
is the magnitude path of the package's Level 2 claim taxonomy. The
vegetation-only envelope is described in the accompanying manuscript's
Supplementary Note 8 (Section S8.2): the calibration's PFT main-effect
and PFT-by-\\\delta^2 H_p\\ interaction coefficients are combined across
all posterior draws to bound how much wax change vegetation
reorganization alone can produce at the site, with no contribution from
precipitation-isotope change.

## Usage

``` r
compute_vegetation_envelope(
  oipc_ref,
  from,
  to,
  model_name = "full_interact_sp",
  n_draws = NULL,
  verbose = TRUE
)
```

## Arguments

- oipc_ref:

  Numeric scalar, the calibration-period `d2H_precip` at the site (per
  mil). Typically extracted from the OIPC raster (Bowen and
  Wilkinson 2002) at the site coordinates; the package does not bundle
  the raster. Held constant across the envelope by construction.

- from:

  Named numeric vector of fractional PFT cover at the baseline interval.
  Names must be exactly `tree`, `shrub`, `grass`, `C4` (case-sensitive).
  Values in \[0, 1\] with `tree + shrub + grass <= 1`; `C4` is an
  independent fraction.

- to:

  Named numeric vector of fractional PFT cover at the test interval.
  Same name and value constraints as `from`.

- model_name:

  Character, name of the calibration model to use. Must contain all
  eight PFT coefficients (PFT main effects and PFT-by-\\\delta^2 H_p\\
  interactions). Default `"full_interact_sp"` is the only shipped model
  that satisfies this requirement.

- n_draws:

  Integer, number of posterior draws to use. `NULL` (default) uses all
  available draws. Subsampling is deterministic (stratified, via
  [`load_posteriors()`](https://bradleylab.github.io/leafwax/reference/load_posteriors.md)).

- verbose:

  Logical, whether to emit progress messages.

## Value

List with

- `envelope_draws` - numeric vector of per-draw signed envelopes (per
  mil).

- `envelope_median` - posterior median of `envelope_draws`.

- `envelope_p975_abs` - `quantile(abs(envelope_draws), 0.975)`, the
  absolute upper bound used by
  [`assess_claim()`](https://bradleylab.github.io/leafwax/reference/assess_claim.md)
  path (b).

- `oipc_ref` - the `oipc_ref` value used (echoed for traceability).

- `delta_pft` - named numeric vector `to - from`.

- `n_draws_used` - integer, number of draws contributing to
  `envelope_draws`.

- `model_name` - the model name used.

- `details` - list with `coefs_summary` (posterior median of each of the
  eight coefficients).

## Details

For each posterior draw the per-draw envelope is
`envelope = sum_k beta_k * delta_pft_k + sum_k beta_d2Hp_x_k * oipc_ref * delta_pft_k`
where `k` indexes the four PFT classes (`tree`, `shrub`, `grass`, `C4`)
and `delta_pft_k = to[k] - from[k]`. The \\\beta\_{\delta^2 H_p} \times
PFT\\ interaction terms are interactions with the precipitation-isotope
calibration slope. The returned
`envelope_p975_abs = quantile(abs(envelope_draws), 0.975)` is the
absolute upper bound used by
[`assess_claim()`](https://bradleylab.github.io/leafwax/reference/assess_claim.md)
path (b) to test whether an observed `|delta_wax|` exceeds what the
supplied PFT scenario alone can produce.

Passing path (b) rejects the vegetation-only null for the supplied
scenario at the site. It does not identify the hydroclimate mechanism,
quantify the precipitation-isotope change, or address sediment-source
change, depositional artifact, compound-source mixing, age-model errors,
evapotranspirative regime change, or seasonality shifts (which
[`assess_claim()`](https://bradleylab.github.io/leafwax/reference/assess_claim.md)
gates with separate fields). The calibration coefficients are derived
from spatial variation across sites; applying them to within-record
temporal vegetation change assumes the same response holds through time
at one location.

## Manuscript reference

Supplementary Note 8 (Section S8.2) of the accompanying manuscript
defines the vegetation-only envelope and the constant-precipitation
framing. The four-level claim taxonomy is an additional package
workflow.

## Examples

``` r
if (FALSE) { # \dontrun{
local({
  old <- options(leafwax.suppress_preview_warning = TRUE)
  on.exit(options(old))

  # Hypothetical: a 30 percentage-point woody-to-grass transition at a
  # site where the OIPC raster lookup gave d2H_precip approximately -60 per mil.
  env <- compute_vegetation_envelope(
    oipc_ref = -60,
    from = c(tree = 0.4, shrub = 0.3, grass = 0.2, C4 = 0.05),
    to   = c(tree = 0.1, shrub = 0.2, grass = 0.5, C4 = 0.20),
    model_name = "full_interact_sp",
    n_draws = 100,
    verbose = FALSE
  )
  vegetation_bound <- env$envelope_p975_abs
})
} # }
```
