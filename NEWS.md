# leafwax 0.2.2

## Documentation and naming-drift cleanup

* All exported `\dontrun{}` and runnable examples now reference v10
  model names (`baseline`, `baseline_sp`, `baseline_env`, ...) instead
  of the v0.1 `b0b1_*` names. The v0.1 names are not available in the
  v10 model registry; the prior examples would have produced
  "model not found" errors if a user tried to run them.
* `R/leafwax-package.R` runnable example now passes `model_name =`
  rather than relying on R's partial-argument matching of `model =`.
* `utils::curlGetHeaders` is fully qualified at the call site to be
  defensive against `warnPartialMatchArgs = TRUE`.
* `get_url_config()` fallback substitutes the real `bradleylab`
  GitHub organization instead of a `[YOUR-USERNAME]` placeholder. The
  fallback only fires for broken installs where `data_urls.json` is
  missing from `inst/extdata/`.
* Drafting-history breadcrumbs ("Phase A", "Phase B", "Codex P2 on
  Phase B") are removed from in-source comments. Substantive content
  is preserved.
* `README.md` rewritten to describe the lazy-load architecture:
  `inst/extdata/posteriors_light/` ships in the tarball and full
  posteriors are downloaded from `bradleylab/leafwax-data` v1.0.1
  (Zenodo) on first use, instead of the prior text claiming the
  package shipped ~10 MB of posteriors directly.
* `.Rbuildignore` widened from `^PLAN_v0\.2\.0\.md$` to
  `^PLAN_v.*\.md$` so future PLAN files are auto-excluded.

# leafwax 0.2.1

## CRAN preparation

* Three-tier posterior resolver wired up: `load_posteriors()` and
  `available_models()` look in heavy posteriors → user cache → preview
  fixture, in that order. Heavy posteriors are now excluded from the
  built tarball (~11 MB → ~1.6 MB).
* `inst/extdata/posteriors_light/` is regenerated as a true 100-draw
  stratified subsample of the heavy posteriors with the full column
  set (the prior version dropped per-knot z columns and silently
  broke spatial inversion). The script that produces it is at
  `data-raw/regenerate_posteriors_light.R`.
* The preview tier is treated as a fixture: `load_posteriors()`,
  `invert_d2H()`, `assess_claim()`, and `detect_change()` warn loudly
  whenever it is in use, naming the function context and the actual
  draw count after thinning. Set `options(leafwax.suppress_preview_warning = TRUE)`
  to silence the warning in batch jobs that have already acknowledged
  the limitation.
* `download_model_data()` now writes `<model>_posterior.rds`
  (singular) to match what `load_posteriors()` reads, and points at
  the bradleylab/leafwax-data archive (concept DOI
  10.5281/zenodo.20085465; v1.0.1 version DOI 10.5281/zenodo.20086180).
  Per-tag raw GitHub URLs are used for direct downloads; Zenodo holds
  the durable archive.
* `jsonlite` moved from `Suggests` to `Imports` (used unconditionally).
* `DESCRIPTION` `Title` reworded to drop the `d2H` abbreviation.
* Internal helpers (`generate_fibonacci_sphere()`,
  `predict_spatial_dual_gp()`, `predict_spatial_mpp()`, the four math
  primitives in `spatial_interpolation.R`, the legacy v0.1
  `load_model_posteriors()`) are now flagged as internal in the help
  index.

# leafwax 0.2.0

## Major release: paleo-record workflow + v10 calibration

`leafwax` 0.2.0 makes the package the operational backend for the
manuscript "Spatial modeling improves the calibration of leaf wax
hydrogen isotopes to precipitation" (Bradley, *Geochimica et
Cosmochimica Acta*). The package now ships the v10 posterior draws
for the 14 hierarchical Bayesian models reported in the manuscript
and exposes the four-phase paleo workflow that the manuscript
references in Sections 4.5.3, 4.5.5, and 4.5.6.

### New functions

* `estimate_sigma_within(d2h_wax, age, baseline_interval, detrend,
  ar1_correction)` -- estimate the within-record residual SD on a
  stationarity-defended baseline interval. Manuscript Section 4.5.3.
* `local_effective_slope(longitude, latitude, model_name, override,
  ceiling = 0.88, n_draws)` -- per-draw local slope at a site, with
  the simple-model ceiling from manuscript Section 4.5.5.
* `estimate_temporal_autocorrelation(d2h_wax, age, method)` -- lag-1
  autocorrelation for the within-record detection threshold.
* `detect_change(reconstruction, age, baseline_interval,
  test_intervals, sigma_within, sigma_analytical, rho_t, beta_eff,
  confidence, magnitudes)` -- within-record d2H_precip detection
  threshold and posterior probability of change.
* `assess_claim(record, claim, reconstruction, ...)` -- walks the
  four-level taxonomy from manuscript Section 4.5.6 and returns the
  highest level a claim survives at, with itemized pass/fail reasons.

### invert_d2H()

* New args `sigma_within`, `sigma_within_sd`, `record_id`, `slope`.
* `sigma_within` enters in leaf-wax per-mil units and propagates
  through `beta_oipc_eff` like the measurement uncertainty (combined
  in quadrature in standardized wax space before inversion).
* `record_id` validates that all input rows are from one site and
  flags coordinate inconsistency under a constant identifier.
* `slope` accepts NULL (model slope), a single point estimate, or a
  per-draw vector; rejects zero / negative / non-finite values.
* The exported wrapper now forwards `return_full`, `credible_level`,
  and `verbose`.

### Routing layer

* `available_models()` exposes the 14 v10 model names from the
  manuscript: `baseline`, `baseline_sp`, `baseline_env`,
  `baseline_env_sp`, `baseline_veg`, `baseline_veg_sp`, `full`,
  `full_sp`, `full_interact`, `full_interact_sp`,
  `elevation_only_sp`, `elevation_c4_sp`,
  `elevation_c4_interact_sp`, `c4_only_sp`.
* `load_posteriors()` derives capability flags (`has_c4`, `has_pft`,
  `has_elevation`, `has_gp`, `has_interaction`) from posterior column
  names rather than name regexes; `full`, `full_sp`, `full_interact`,
  and `full_interact_sp` correctly report their vegetation and
  interaction effects.
* `load_posteriors()` subsamples deterministically (stratified
  thinning), so two calls with the same `model_name` and `n_draws`
  return the same draws subset. This is what lets
  `local_effective_slope(..., n_draws = N)` pair by position with
  `invert_d2H(..., n_posterior_draws = N, slope = ...)`.

### Data

* All 14 v10 model posterior draws shipped as
  `inst/extdata/posteriors/<model>_posterior.rds`.
* 125-knot Fibonacci-sphere knot files for the 9 spatial models
  shipped as `inst/extdata/spatial_metadata/<model>_knots.rds`.
* Standardisation parameters shipped as
  `inst/extdata/scaling_params.rds`.
* Lake Malawi LS11KOMA Common-Era leaf-wax record bundled at
  `inst/extdata/example_records/LS11KOMA_d2H.csv` for the vignette.

### Vignettes

* New `paleo-record-workflow.Rmd`: end-to-end seven-step workflow on
  the Lake Malawi record (load -> sigma_within -> slope -> inversion
  -> detect_change -> assess_claim -> plot).
* The three v0.1.0 vignettes (Getting Started, Advanced Usage, Model
  Descriptions) are archived under `vignettes/_archive_v0.1.0/` and
  excluded from the build pending a v0.3 rewrite.

### Tests

* New testthat suites for the v10 routing (`test-v10-posteriors.R`)
  and each phase of the paleo workflow (`test-phase-{a,b,c,d}.R`).
* 275 PASS / 0 FAIL / 0 WARN.
* The four v0.1.0 testthat files referencing legacy model names and
  `invert_d2h()` signatures are archived under
  `tests/_archive_v0.1.0/` for reference.

### `R CMD check`

Status: 1 NOTE (extdata size ~10.6 MB, expected -- the shipped v10
posteriors). All ERRORs and WARNINGs from the v0.1.0 baseline are
resolved.

### Codex review

Each phase commit was reviewed via `codex review --commit HEAD` and
the findings (1 P2 on Phase F, 2 P2s on Phase A, 2 P2s on Phase B,
3 P2/P3s on Phase C, 3 P2s on Phase D) were addressed in dedicated
follow-up commits. Phase E review returned clean.

# leafwax 0.1.0

Initial v0.1.0 release. See `tests/_archive_v0.1.0/README.md` and
`vignettes/_archive_v0.1.0/` for archived material from this release.
