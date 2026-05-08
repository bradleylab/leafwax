# leafwax v0.2.0 — paleo-record workflow

Build plan for extending the `leafwax` package from per-sample inversion
(v0.1.0) to a full downcore paleo-record workflow with claim-taxonomy
assessment, supporting the manuscript revision at
`bradleylab/leafwax-spatial`.

Branch: `feat/v10-posteriors-and-paleo-workflow`.

------------------------------------------------------------------------

## Goal

A working paleohydrologist can hand `leafwax` a published δ²H_wax record
(downcore series + age model + site coordinates) and a claimed
hydroclimate interpretation, and get back:

1.  A within-record δ²H_precip posterior trajectory with full
    uncertainty propagation.
2.  A defensibility verdict: at which level (1–4) of the claim taxonomy
    the original interpretation actually holds.
3.  Diagnostics: σ_within from a stationary baseline interval, lag-1
    temporal autocorrelation ρ_t, the local effective slope at the site,
    and the change-detection threshold under those conditions.

The package becomes the operational artifact for Sections 4.5.3, 4.5.5,
and 4.5.6 of the manuscript (the σ_within obligation, the slope ceiling
under stationarity, and the four-level claim taxonomy). The manuscript
references the package; the package implements what the manuscript
demands.

## What’s in v0.1.0 (foundation we keep)

- [`invert_d2H()`](https://bradleylab.github.io/leafwax/reference/invert_d2h.md)
  /
  [`invert_d2h()`](https://bradleylab.github.io/leafwax/reference/invert_d2h.md)
  — per-sample inversion engine.
- [`load_posteriors()`](https://bradleylab.github.io/leafwax/reference/load_posteriors.md)
  — reads `inst/extdata/posteriors/<model>_posterior.rds`.
- [`predict_spatial_mpp()`](https://bradleylab.github.io/leafwax/reference/predict_spatial_mpp.md)
  — Gaussian-process kriging from knot effects to a new location
  (modified Predictive Process).
- [`available_models()`](https://bradleylab.github.io/leafwax/reference/available_models.md),
  `model_details()`,
  [`select_best_model()`](https://bradleylab.github.io/leafwax/reference/select_best_model.md)
  — model metadata routing.
- 14 model variants in extdata (older fit; needs replacement, see Phase
  F).

## Compatibility findings

- v10 posteriors at
  `leafwax_gca_working/results/c2_run_20260501/<model>/posterior_draws.rds`
  are `draws_array` (iterations × chains × variables). Package expects
  `draws_df` (rows = draws, cols = named parameters). Conversion is
  `posterior::as_draws_df(d)` — straightforward.
- v10 model uses 125 knots; package extdata is from a 120-knot fit. New
  `<model>_knots.rds` files needed.
- v10 parameter names match what the package code reads: `beta_0`,
  `beta_oipc`, `sigma`, `lambda_decay`, `effective_scale_km`,
  `ls_intercept_km`, `ls_slope_km`, `sigma_intercept_spatial`,
  `sigma_slope_spatial`, plus `z_intercept_spatial[1..125]` and
  `z_slope_spatial[1..125]` for the spatial draws (and `mu[1..N]` for
  fitted values, which we drop on conversion).
- For non-spatial models (`baseline`, `baseline_env`, `baseline_veg`,
  `full`, `full_interact`) there are no spatial knot params; the
  posterior has fewer columns. `<model>_knots.rds` should not be
  produced for these.

## Phases

### Phase F — v10 posterior packaging (prerequisite, ~1 day)

Goal: every v10 model loadable via
[`load_posteriors()`](https://bradleylab.github.io/leafwax/reference/load_posteriors.md)
with no API break for downstream code.

Deliverables:

- `data-raw/convert_v10_posteriors.R` — script that:
  1.  Iterates the 14 model directories under
      `<gca-working>/results/c2_run_20260501/`.
  2.  Reads each `posterior_draws.rds` as `draws_array`.
  3.  Subsets to global parameters the package consumes (`beta_0`,
      `beta_oipc`, `sigma`, `lambda_decay`, `effective_scale_km`,
      `ls_intercept_km`, `ls_slope_km`, `sigma_intercept_spatial`,
      `sigma_slope_spatial` for spatial models; plus β coefficients for
      vegetation/elevation models).
  4.  For spatial models, also extracts `z_intercept_spatial[i]` and
      `z_slope_spatial[i]` for i=1..125 as a draws-by-knots matrix.
  5.  Converts to `draws_df`; writes
      `inst/extdata/posteriors/<model>_posterior.rds`.
  6.  Writes 125-knot Fibonacci coordinates to
      `inst/extdata/spatial_metadata/<model>_knots.rds` for spatial
      models. Knots are model-independent (same Fibonacci sphere across
      all spatial variants), so this can be a single shared object — but
      keep the per-model file pattern so code that reads them doesn’t
      change.
- Update `inst/extdata/spatial_models_metadata.json` to reflect 125-knot
  fits and v10 lineage.
- Update `inst/extdata/data_info.rds` so
  [`load_posteriors()`](https://bradleylab.github.io/leafwax/reference/load_posteriors.md)
  reports v10 lineage.
- Smoke test:
  [`library(leafwax); res <- invert_d2H(d2h_wax = -180, d2h_wax_sd = 3, longitude = -90, latitude = 38, model_name = "baseline_sp")`](https://github.com/bradleylab/leafwax)
  runs and returns a credible-interval result close to what the v10
  paper reports for that test point.
- New tests under `tests/testthat/test-v10-posteriors.R` covering all 14
  models load + a single inversion runs + spatial models give different
  results from non-spatial at the same input.

### Phase A — σ_within + downcore time series (~1 day)

Goal: same-site time series gets one consistent spatial draw and a
user-supplied σ_within instead of the global posterior σ.

API additions:

- `invert_d2H(..., sigma_within = NULL, sigma_within_sd = NULL, record_id = NULL)`:
  - When `sigma_within` is supplied, replace the residual σ in the
    posterior predictive with `sigma_within` (or sample from
    `Normal(sigma_within, sigma_within_sd)` per draw if supplied).
  - When `record_id` is non-NULL and the same value appears across all
    rows, sample the spatial GP once per draw at that site and reuse
    across the series, rather than redrawing per row.
- `estimate_sigma_within(d2h_wax, age, baseline_interval = NULL, detrend = c("none", "linear", "loess"), ar1_correction = TRUE)`:
  - Default behavior: if `baseline_interval` is NULL, treat the full
    record as the baseline (warn the user that this conflates real
    variability with noise).
  - With explicit `baseline_interval`, subset and estimate σ from the
    detrended residuals with optional AR1 correction
    (`σ_eff = σ_naive × √(1 - ρ²)`).
  - Returns named list: σ_within (point estimate), σ_within_se,
    n_baseline, ρ_t_baseline, method.

Tests:

- σ_within \< σ_global on a synthetic stationary series.
- σ_within → 0 on a perfectly autocorrelated series after AR1
  correction.
- `record_id` constancy gives reduced reconstruction variance vs per-row
  spatial draws.

### Phase B — local effective slope (~0.5 day)

Goal: a paleohydrologist can extract the model’s site-specific slope
posterior and override it with a defended local value, capped at α=0.88
by default.

API additions:

- `local_effective_slope(longitude, latitude, model_name, override = NULL, ceiling = 0.88, n_draws = NULL)`:
  - Returns a per-draw slope vector at the site by combining the global
    `beta_oipc` posterior with the spatial slope GP prediction
    (`z_slope_spatial` projected via `predict_spatial_mpp`).
  - If `override` is supplied (single value or per-draw vector), use it
    instead of the model’s slope.
  - If `ceiling` is non-NULL, truncate any draw above the ceiling. Warn
    if \>5% of draws are truncated (suggests the user’s defended slope
    or the model is inconsistent with the simple-model bound).
- `invert_d2H(..., slope = NULL)` — accept either NULL (use model
  slope), a numeric value (use as fixed point estimate), or a vector of
  length n_draws (use per-draw).

Tests:

- Slope from `local_effective_slope` matches a hand-rolled extraction on
  baseline_sp.
- Ceiling truncation reports the count of truncated draws.
- Override propagates correctly through `invert_d2H`.

### Phase C — change detection with autocorrelation (~0.5 day)

Goal: given a downcore record + reconstruction posterior, report a
within-record threshold for δ²H_precip change detection at user-chosen
confidence levels.

API additions:

- `detect_change(record, reconstruction, baseline_interval = NULL, test_intervals = NULL, confidence = 0.95)`:
  - Returns the posterior probability that ΔδD_precip between
    `baseline_interval` and each `test_intervals` element exceeds
    user-supplied magnitudes.
  - Reports the 95% within-record detection threshold using the formula
    in §4.5.3 of the manuscript
    (`1.96 × √(2(1-ρ_t)) × √(σ_within² + σ_analytical²) / β_eff`).
- `estimate_temporal_autocorrelation(d2h_wax, age, method = c("ar1", "lomb_scargle"))`
  — handles unevenly sampled series.

Tests:

- ρ_t recovery on synthetic AR(1) series.
- Threshold sensitivity matches the curves in Figure 5.

### Phase D — claim taxonomy (~0.5 day)

Goal: given a record + a claim spec, return a Level 1–4 verdict and
itemize what’s defended vs missing.

API additions:

- `assess_claim(record, claim, reconstruction = NULL, ...)`:
  - `claim` is a list with fields `level` (1–4 if user is asserting),
    `magnitude` (numeric, ‰), `interval_baseline`, `interval_test`,
    optional `corroborating_proxies`, `vegetation_stationary` (logical
    - evidence string), `seasonal_source_stationary`, etc.
  - Runs the inversion if `reconstruction` is NULL.
  - Walks the four levels checking the obligations from §4.5.6 of the
    manuscript:
    - L1: change exceeds analytical + σ_within?
    - L2: alternatives excluded by `corroborating_proxies`?
    - L3: defended slope + σ_within + propagated uncertainty?
    - L4: independent stationarity evidence supplied?
  - Returns the highest level the claim survives at, with itemized
    pass/fail reasons.

Tests:

- A synthetic record with a 50‰ wax shift + known stationary vegetation
  - corroborating speleothem reaches Level 4.
- A synthetic record with a 5‰ wax shift over 2 samples and no
  corroboration drops to Level 1.

### Phase E — paleo-workflow vignette (~0.5 day)

`vignettes/paleo-record-workflow.Rmd` — step-by-step on a real Iso2k
record. Recommended first example: Lake Malawi (LS11KOMA) — Common Era,
~3‰ within-record SD, makes the marginal-claim case concretely. Optional
second example for contrast: Lake N3 (LS16THN301) — 8 kyr Holocene, 35‰
within-record SD, real signal. Both are already extracted at
`/tmp/leafwax_records/<dataset>__d2H.csv`.

The vignette walks: 1. Read the downcore series. 2. Estimate σ_within
from a stationarity-defended baseline interval. 3. Extract / defend the
local effective slope. 4. Run
[`invert_d2H()`](https://bradleylab.github.io/leafwax/reference/invert_d2h.md)
with `record_id`, `sigma_within`, and `slope` set. 5. Run
[`detect_change()`](https://bradleylab.github.io/leafwax/reference/detect_change.md)
for the magnitudes claimed in the original publication. 6. Run
[`assess_claim()`](https://bradleylab.github.io/leafwax/reference/assess_claim.md)
against the published claim spec. 7. Plot the reconstructed δ²H_precip
with within-record uncertainty.

### Phase G — release (~0.25 day)

- Bump DESCRIPTION to 0.2.0.
- Update `NEWS.md`.
- Update `README.md` examples.
- Tag `v0.2.0` and push the feature branch as a PR.
- The manuscript’s package URL (<https://github.com/bradleylab/leafwax>)
  resolves to a release with the paleo workflow visible.

## Open questions for the operator

1.  **Knot count**: the manuscript says 125 knots; the package extdata
    was built around 120. Confirm 125 is canonical for v10. If yes, the
    converter regenerates `_knots.rds` files at 125. The Fibonacci
    sphere coordinates are deterministic given `n_points`, so this is
    safe.
2.  **Default σ_within behavior**: when the user does not supply
    σ_within, should the package (a) error and require explicit
    choice, (b) fall back to the global σ with a warning, or (c)
    auto-estimate from the record using the full series as baseline
    (with warning)? Default
    2.  is the least-disruptive but also the least-aligned with the
        manuscript’s “must defend” framing. (a) matches the manuscript
        best but is unfriendly. Recommendation: (b) with a loud one-time
        warning per session.
3.  **Claim taxonomy strictness**: does L4 require an independent
    isotope proxy specifically, or can independent vegetation evidence
    (pollen, biomarker stability) qualify? The manuscript says
    “typically from an independent proxy responsive to one of the
    alternatives” — interpret broadly or strictly?
4.  **Vignette scope**: one record (Lake Malawi only) or two-record
    contrast (Lake Malawi + Lake N3)? Two records is more illuminating
    but doubles the vignette length.
5.  **CRAN**: target CRAN release in v0.2.0 or stay GitHub-only? CRAN
    would constrain dependencies and require all-platform testing.

## What does NOT change

- Per-sample
  [`invert_d2H()`](https://bradleylab.github.io/leafwax/reference/invert_d2h.md)
  API stays backwards-compatible — new args are optional with sensible
  defaults.
- All 14 model variants stay available.
- The Shiny app keeps working (may need a downcore tab eventually but
  that’s out of scope for v0.2.0).
- The manuscript’s existing references to the package
  (<https://github.com/bradleylab/leafwax>) continue to resolve.
