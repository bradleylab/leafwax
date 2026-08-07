# Assess a paleoclimate claim against the leaf-wax taxonomy

Walks the package's four-level taxonomy and reports the highest level a
claim survives at. The taxonomy is:

- Level 1: a leaf-wax delta-2-H change occurred between two intervals.
  Defensible when the change exceeds analytical uncertainty.

- Level 2: the wax change is consistent with a directional hydroclimate
  change. Requires (i) sediment-source change ruled out by independent
  evidence (`sediment_source_ruled_out`), AND (ii) depositional artifact
  ruled out by independent evidence (`depositional_artifact_ruled_out`),
  AND EITHER (a) named corroborating evidence against vegetation
  reorganization via `corroborating_proxies` (the original path), OR (b)
  demonstration that the observed wax shift exceeds the vegetation-only
  envelope computed from a user-supplied PFT-change scenario
  (`level2_vegetation_path`; see
  [`compute_vegetation_envelope()`](https://bradleylab.github.io/leafwax/dev/reference/compute_vegetation_envelope.md)
  and manuscript Supplementary Section S8.2).

- Level 3: the wax change implies a quantitative delta-2-H_precip
  magnitude. Requires a defended local effective slope and explicit
  uncertainty propagation through the inversion. When `reconstruction`
  is NULL the function calls
  [`invert_d2H()`](https://bradleylab.github.io/leafwax/dev/reference/invert_d2h.md)
  itself.

- Level 4: the magnitude is uniquely attributable to precipitation
  isotope change rather than to vegetation, source-water seasonality, or
  evapotranspirative enrichment. Requires independent stationarity
  evidence for each non- precipitation control over the interval.

## Usage

``` r
assess_claim(
  record,
  claim,
  reconstruction = NULL,
  longitude = NULL,
  latitude = NULL,
  model_name = "baseline_sp",
  ...
)
```

## Arguments

- record:

  Data frame (or list) with at least `d2h_wax` and `age` columns of
  equal length. `d2h_wax_err` is optional; defaults to
  `claim$sigma_analytical` per row.

- claim:

  Named list specifying the claim. Required fields: `level` (integer
  1-4, the level the user is asserting), `interval_baseline` (length-2
  numeric c(min, max) age window), `interval_test` (length-2 numeric age
  window). Optional fields, used by higher levels: `sigma_analytical`
  (default 3), `rho_t` (default 0; from
  [`estimate_temporal_autocorrelation()`](https://bradleylab.github.io/leafwax/dev/reference/estimate_temporal_autocorrelation.md)),
  `beta_eff` (numeric scalar; required at Level 3+), `confidence`
  (default 0.95), `magnitude_precip` (numeric, the precip-space
  magnitude the user asserts; required at Level 3+),
  `sediment_source_ruled_out`, `depositional_artifact_ruled_out` (each a
  list with `value` (TRUE) and a non-empty `evidence` string; BOTH
  required at Level 2+ regardless of which Level 2 path is used),
  `corroborating_proxies` (list, used at Level 2 path (a); the test is
  non-empty + named), `level2_vegetation_path` (list, used at Level 2
  path (b); must contain `vegetation_scenario = list(from, to)` with
  named numeric vectors over `{tree, shrub, grass, C4}` and an optional
  `evidence` string. The claim must also supply `oipc_ref` (numeric
  scalar, calibration-period d2H_precip at the site, per mil) at the top
  level. An optional `level2_vegetation_path$model_name` selects the
  calibration model used for the envelope; default
  `"full_interact_sp"`.), `vegetation_stationary`,
  `seasonal_source_stationary`, `evapotranspirative_stationary` (each a
  list with `value` (TRUE) and a non-empty `evidence` string; required
  at Level 4).

- reconstruction:

  Optional output of `invert_d2H(..., return_full = TRUE)` on the
  record. When NULL and the claim's level is 3 or 4, the function runs
  the inversion itself.

- longitude, latitude:

  Site coordinates, used only when `reconstruction` is NULL.

- model_name:

  Model to use when running the inversion (default "baseline_sp").

- ...:

  Additional args forwarded to
  [`invert_d2H()`](https://bradleylab.github.io/leafwax/dev/reference/invert_d2h.md).
  For an internally constructed Level 3+ reconstruction these must
  include an explicit `prior`, positive `n_inverse_samples`, and `seed`.

## Value

A list with elements:

- `highest_level` - integer in 0:4. 0 means even Level 1 did not clear.

- `levels` - data frame, one row per level, with columns `level`,
  `passed` (logical), `summary` (one-line reason).

- `details` - per-level lists of computed quantities (e.g., delta_wax,
  threshold, p_exceed, missing fields).

- `claim` - the (validated) claim object.

## Details

Use this when a colleague claims that a downcore record shows a specific
d2H_precip shift and you want a structured check of which levels of the
taxonomy that claim actually clears.
