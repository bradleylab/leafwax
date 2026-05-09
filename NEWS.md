# leafwax 0.2.2

## Bug fixes (runtime correctness)

* `invert_d2H()` and `invert_d2h()`: the reported credible interval
  did not include the model's posterior residual SD `sigma`, so the
  reported `prediction_interval_width` was the wrong quantity for
  single-site reconstruction. At a typical site this gave intervals
  roughly an order of magnitude narrower than the manuscript's
  per-site uncertainties. The wax-error draw now follows manuscript
  supplement Section S4.1 Eq. 7: `analytical^2 + sigma_residual^2`
  combined in quadrature, with parameter and spatial uncertainty
  carried through the per-iteration posterior draws. This applies
  uniformly to absolute single-point reconstruction and to
  within-record contrasts; the spatial GP intercept's contribution
  cancels in any contrast computed from the returned
  `posterior_draws` (manuscript Section 4.5.3).
* `detect_change()`: the threshold-formula argument is renamed from
  `sigma_within` to `sigma_residual` to match the manuscript's
  framework. Pass the model's posterior `sigma` (approximately 16
  per mil for the spatial models). The function no longer requires
  the reconstruction to be built in any special mode.
* `assess_claim()`: dropped the `claim$sigma_within` field. The L1
  threshold uses analytical uncertainty alone (manuscript Section
  4.5.3); L3 still uses the inversion's posterior_draws but no
  longer requires a separate within-record SD.
* Removed `estimate_sigma_within()`. Within-record uncertainty in
  this framework comes from the calibration's `sigma_residual`
  combined with the spatial GP intercept's cancellation in a
  contrast; there is no separate record-specific SD to estimate.
* `invert_d2H_ensemble()`: rewritten to fix multiple bugs in the
  default-args path. The previous default `models =` argument used
  v0.1 names that are not in the v10 registry; replaced with
  `c("full_sp", "full_interact_sp", "elevation_c4_interact_sp")`.
  Validation accessed `available_models()$model`, but
  `available_models()` returns a character vector, so the subset was
  always `NULL` and validation silently skipped; now reads the vector
  directly. The inner `invert_d2H()` call did not pass
  `return_full = TRUE`, so the pooling step downstream read
  `$posterior_draws` from a summary data frame and got `NULL`; now
  forces `return_full = TRUE`. The pooling step itself flattened the
  per-model `posterior_draws` matrix across BOTH the draw and site
  axes, collapsing multi-site input to one scalar mean shared across
  all sites; now pools per-site, per-draw across models. The pool
  also previously concatenated all per-model draws and then sampled,
  which gave models with more draws (e.g. 1000-draw heavy tier vs.
  100-draw preview tier) a proportionally larger share of the
  "equal" pool; now resamples each model to a uniform `n_target / k`
  draws first and concatenates. **Return shape changed** (see
  Breaking changes below).
* `compare_models()`: default `models =` argument referenced v0.1
  names; replaced with `c("baseline", "baseline_sp", "full_sp")`.
  Several latent failures also blocked the default invocation. A
  `verbose` partial-match conflict when forwarding `...` to
  `predict_d2h_precip()` was producing
  `formal argument "verbose" matched by multiple actual arguments`;
  switched to `do.call()` with a filtered extra-args list. Single-row
  input made the per-model means a length-N vector with `NULL` `dim()`,
  tripping the row-wise `apply()`; coerced to a 1xN matrix in that
  case. The per-model column rename for `return_all = TRUE` was being
  applied unconditionally and broke the ensemble-summary path; now
  only applied on the `return_all = TRUE` path. A user typo in `...`
  (e.g. `verb = FALSE`) used to cause every per-model `do.call()` to
  fail with "unused argument", the per-model `tryCatch` would swallow
  each failure as a warning, and the function would abort with the
  misleading "All models failed"; `compare_models()` now validates
  `...` against `predict_d2h_precip()`'s formals up front and reports
  unknown argument names with a clear error before the model loop
  runs. The `models_used` field of the returned ensemble summary
  used to report the originally requested set rather than the models
  that actually contributed; now reports `names(model_results)` so
  partial-failure runs are not silently misreported.
* `predict_d2h_precip()` and `invert_d2H()`: the
  `c4_fraction * 100` conversion was unconditional, so a `NULL`
  input became `numeric(0)` and tripped a spurious capability-mismatch
  warning inside the core inversion. Both wrappers now keep `NULL` as
  `NULL`. They also now reject vector-length mismatches between
  `c4_fraction` and `d2H_wax` (was: silent R recycling with a generic
  warning) and validate that user inputs lie in `[0, 1]`. The
  out-of-range error names the offending maximum value and tells the
  caller to divide by 100 if the input is on the percent scale.
* `get_data_manifest()`: previously returned `list(files = list())`
  on download failure, which downstream `verify_data_integrity()`
  read as "no checksums available, allow the file." Now returns
  `NULL` with a `warning()`; `verify_data_integrity()` treats `NULL`
  as "verification skipped" and warns explicitly.
* `check_data_cache()`, `list_cached_models()`, and
  `get_cache_files()`: `download_model_data()` writes a single
  posterior file per model at
  `posteriors/<model>_posterior.rds`, but these three helpers were
  still looking for the v0.1 layout
  (`metadata/<model>_metadata.rds`,
  `posteriors/<model>_2000draws.rds`, and
  `posteriors_full/<model>_complete.rds`). After any successful
  download they reported the model as absent. The three helpers now
  read the canonical v0.2 layout. The `data_type` argument of
  `check_data_cache()` is retained for API compatibility but is now
  a no-op.
* `data_urls.json`: `base_url_latest` previously pointed at the
  `main` branch of `bradleylab/leafwax-data` while `manifest_url`
  was pinned to `v1.0.1`. Aligned both to `v1.0.1` so a future
  non-no-op `verify_data_integrity()` cannot trip on drift between
  latest-branch files and a v1.0.1 manifest.
* `clear_download_cache()` no longer creates the cache directory
  before checking that it exists. Replaced the default
  `get_cache_dir()` call with `get_cache_dir(create = FALSE)`.

## Bug fixes (post-review pass)

These fixes resolve issues surfaced by the pre-CRAN review pass.

* `invert_d2H_ensemble()` aborted with
  "formal argument 'return_full' matched by multiple actual arguments"
  whenever the caller passed `return_full` (or `model_name`) through
  `...`. The wrapper now strips both names from `...` before the
  per-model loop. The function also now warns when models contribute
  unequal draw counts and pools each model to the median count rather
  than the first model's count.
* `process_sequential()` referenced `processing_time` outside the
  `if (progress) {...}` block where it was assigned, throwing
  "object 'processing_time' not found" whenever
  `batch_predict(..., progress = FALSE)` was called.
* `batch_predict()` aborted with
  "numbers of columns of arguments do not match" when one chunk
  errored to the smaller fallback shape and another succeeded with
  the full schema. The combine step now uses a column-tolerant
  helper (`.rbind_chunks`) that pads missing columns with NA.
* `detect_change()` aborted on the same `rbind` mismatch when an
  empty `test_interval` was paired with `magnitudes`. The empty-
  interval branch now appends NA magnitude columns so the column set
  matches populated rows.
* The "elevation" code path in `invert_d2h()` was unreachable for
  every v10 model. None of the 14 fitted posteriors carry
  `beta_elev` columns, so `model$elevation` was never populated and
  the function unconditionally hit a "knots not found" warning that
  silently dropped any user-supplied elevation. Removed the dead
  spline branch; `has_elevation` is now derived from the actual
  posterior columns and is `FALSE` for every shipped v10 model. The
  "env" variants instead carry a `beta_precip` term, exposed via
  `metadata$has_precip`.
* `validate_inputs()`: the validated PFT vectors were dropped from
  the returned list when the model used the v10 `has_vegetation`
  flag (rather than the legacy `has_pft`). The output now honours
  both names.
* `download_with_progress()`: the error handler called `close()` on
  `con_in` / `con_out` unconditionally, raising a secondary error
  inside the handler when either had not yet been opened. The
  handler now only closes connections that were actually opened.

## Repo cleanup

* Removed the unreachable lookup-table subsystem
  (`R/lookup_tables.R`, `R/lookup_integration.R`, the
  `predict_spatial_mpp()` deprecated stub, and the `use_lookup`
  argument of `predict_d2h_precip()`). The path was never wired to a
  shipping data archive; spatial predictions now always go through
  `predict_spatial_dual_gp()` against the live posterior.
* Removed `clear_data_cache()`. Use `clear_download_cache()` instead;
  the two helpers were near-duplicates with no behavioural
  difference.
* Removed dead exports: `batch_invert_d2h()`, `monitor_memory()`,
  `verify_data_integrity()`, `setup_leafwax_data()`,
  `select_best_model()`, `get_model_recommendations()`. None had
  callers in the package and several relied on broken legacy paths.
* Removed the misleading text-progress bar in `predict_d2h_precip()`:
  it jumped from 0% to 100% in a single step regardless of work
  done, because the inversion runs in one pass with no per-iteration
  callback. The `progress` argument is retained but is now a no-op
  at this layer; chunked progress reporting is still driven by
  `batch_predict()`.

## Internal cleanup

* `LEAFWAX_DEFAULTS` (in `R/zzz.R`) is now the single source of
  truth for `leafwax.*` user options. `leafwax_config()` and
  `leafwax_set_config()` derive their option lists from it, so
  `suppress_preview_warning` (and any future option) round-trips
  without manual list maintenance.
* Capability flags are now derived from the actual posterior columns
  in `load_posteriors()`. `model_compatibility.R` keeps the
  name-based view for callers that need expected-schema info without
  loading the model; the two views agree on what each shipped v10
  variant contains.
* `get_cache_info()` now classifies cache files using the v0.2
  download layout (`posteriors/<model>_posterior.rds`,
  `spatial_metadata/<model>_knots.rds`, `manifest.json`). The
  previous regex matched only legacy v0.1 names, so the function
  silently classified every real cache entry as "other".
* `load_posteriors()` now warns when it falls back to a freshly
  generated 125-knot Fibonacci sphere because the model's knot file
  is missing. The substituted knots are not byte-identical to the
  v10 fit, so silent substitution is methods drift.
* `invert_d2h()` warns (was: a print statement) when
  `model$scaling` is missing and the inversion uses the conservative
  `PLACEHOLDER_SCALING` defaults — those scales are not the v10
  fitted ones and reconstructions will not match the published
  calibration.
* Magic numbers (analytical default 3 per mil, 125 spatial knots,
  default C4 percent, default PFT split, placeholder scaling) are
  promoted to named constants in `R/constants.R`.

## Repo organization

* Untracked `leafwax.Rcheck/` artifacts (the directory is now
  matched by `*.Rcheck/` in `.gitignore`).
* Removed `README_EXAMPLES.md`, `test_direct.R`, `test_inversion.R`
  from the repo root — orphaned scratch artifacts already excluded
  from the tarball via `.Rbuildignore`.
* Moved `PLAN_v0.2.0.md` and `PLAN_v0.2.2.md` into `dev-notes/`.
* Removed the archived v0.1.0 test directory
  (`tests/_archive_v0.1.0/`).
* Added `cran-comments.md`.
* `.Rbuildignore` cleaned of stale entries
  (`vignettes/_archive_v0.1.0`, `test_*.R`,
  `README_EXAMPLES.md`, `PLAN_v*.md` — paths that no longer
  exist or are now covered by directory-level rules).

Regression tests covering these fixes are in
`tests/testthat/test-cleanup-v022.R`.

## Breaking changes

* `invert_d2H()` reported intervals are now wider (the posterior
  predictive includes the residual `sigma`). The point estimate
  (`d2h_precip_mean`, `d2h_precip_median`) is unchanged;
  `d2h_precip_sd`, `d2h_precip_lower`, `d2h_precip_upper`, and
  `prediction_interval_width` are wider.
* `invert_d2H()` and `invert_d2h()`: removed `sigma_within` and
  `sigma_within_sd` arguments. The function applies the
  calibration's `sigma_residual` directly.
* `detect_change()`: renamed argument `sigma_within` to
  `sigma_residual`.
* `assess_claim()`: removed required `claim$sigma_within` field.
* `estimate_sigma_within()` is removed.
* `invert_d2H_ensemble()` return shape changed. `posterior_draws` is
  now an `n_draws x n_sites` matrix (previously: a flat vector of
  length `n_draws` for single-site, silently corrupted for multi-site).
  `ensemble_summary` is now a data frame with one row per site
  (previously: a list of scalars, only correct for single-site input).
  The list of pooled models is now exposed at the top level as
  `models_used`; the previous `ensemble_summary$models_used` is gone.
  Single-site code that read `e$ensemble_summary$mean` continues to
  work — the data frame has one row, and `$mean` returns its single
  value. Multi-site code is breaking by definition: callers were
  reading wrong numbers before this fix.
* The exported data objects `model_metadata`, `mini_posteriors`, and
  `mini_lookup_table` are removed. They held v0.1 model names and
  were not used by any v10 code path; metadata is now exposed via
  `get_all_model_metadata()` and posteriors via `load_posteriors()`
  (with the lazy-load resolver). Users still calling
  `data(model_metadata)` will see "data set not found" and should
  switch to `get_all_model_metadata()`.
* The legacy v0.1 helpers `load_model_posteriors()`,
  `check_model_data()`, `use_example_data()`, and
  `get_model_size_estimate()` are removed. New code should call
  `load_posteriors()`, `check_data_cache()`, and the lazy-load
  download path. The synthetic-data fallback inside
  `use_example_data()` is also gone; missing posteriors now produce
  an explicit error instead of fabricated draws.
* The internal `.download_model_data_v0_1()` and its private helper
  `get_download_files()` are removed (the exported
  `download_model_data()` in `R/download_data.R` is unchanged).
* `validate_inputs()`'s default `model_name` changed from `"b0b1"` to
  `"baseline"`. The previous default was a v0.1 name not in the v10
  registry, so calls that relied on the default would have errored
  in `get_all_model_metadata()` lookup; the new default is the
  closest v10 equivalent.
* `compare_models()`'s NULL-fallback model set changed from v0.1
  names (`"b0b1"`, `"b0b1_elev"`, `"b0b1_sp"`) to v10
  (`"baseline"`, `"baseline_sp"`, `"full_sp"`). Same rationale: the
  old default was unreachable.
* The lookup-table API is removed (`create_lookup_table()`,
  `use_lookup_if_available()`, `predict_spatial_mpp()`,
  `validate_lookup_table()`, `get_spatial_params()`,
  `cache_all_lookup_tables()`, `benchmark_lookup()`,
  `generate_global_grid()`, plus the `print.leafwax_lookup_table`
  method). The path was never wired to a published data archive; no
  v0.2 caller used it.
* `predict_d2h_precip()`: removed the `use_lookup` argument (no-op
  since the lookup-table subsystem is gone).
* `clear_data_cache()` removed; use `clear_download_cache()`.
* `batch_invert_d2h()`, `monitor_memory()`, `verify_data_integrity()`,
  `setup_leafwax_data()`, `select_best_model()`, and
  `get_model_recommendations()` are removed.

## Documentation and naming-drift cleanup

* All exported `\dontrun{}` and runnable examples now reference v10
  model names (`baseline`, `baseline_sp`, `baseline_env`, ...) instead
  of the v0.1 `b0b1_*` names. The v0.1 names are not available in the
  v10 model registry; the prior examples would have produced
  "model not found" errors if a user tried to run them.
* `R/leafwax-package.R` runnable example now passes `model_name =`
  rather than relying on R's partial-argument matching of `model =`.
* `curlGetHeaders` qualified as `base::curlGetHeaders` at the call
  site (it is a base function, not a `utils` export).
* `get_url_config()` fallback substitutes the real `bradleylab`
  GitHub organization instead of a `[YOUR-USERNAME]` placeholder. The
  fallback only fires for broken installs where `data_urls.json` is
  missing from `inst/extdata/`.
* `inst/extdata/model_info.json` description for `c4_fraction`
  rewritten to match the actual contract (fraction `[0, 1]` on the
  public API, converted to percent internally).
* Drafting-history breadcrumbs ("Phase A", "Phase B", "Codex P2 on
  Phase B") are removed from in-source comments. Substantive content
  is preserved.
* `inst/examples/` (four v0.1 example scripts) and
  `data-raw/{copy_posteriors,prepare_external_data,prepare_external_data_quick,prepare_package_data,_legacy_extract_spatial_metadata_120knot}.R`
  + `data-raw/upload_instructions.md` + `data-raw/README.md` removed.
  The v10 vignette `paleo-record-workflow.Rmd` is now the canonical
  end-to-end example.
* `README.md` rewritten to describe the lazy-load architecture:
  `inst/extdata/posteriors_light/` ships in the tarball and full
  posteriors are downloaded from `bradleylab/leafwax-data` v1.0.1
  (Zenodo) on first use, instead of the prior text claiming the
  package shipped ~10 MB of posteriors directly.
* `.Rbuildignore` widened from `^PLAN_v0\.2\.0\.md$` to
  `^PLAN_v.*\.md$` so future PLAN files are auto-excluded; the
  now-obsolete `^inst/examples$` line is removed.
* `_pkgdown.yml` reference index pruned: the deleted v0.1 helpers,
  the three deleted data exports, and the "legacy" framing on the
  lower-level helpers section are removed.
* `tests/testthat/helper-data.R` pruned to just the
  `leafwax.suppress_preview_warning` option setter; the `b0b1`-default
  mock helpers (`create_mock_metadata`, `create_mock_posteriors`,
  `create_mock_lookup_table`, `create_test_data`,
  `skip_on_cran_and_ci`, `model_available`) were dead code, not called
  by any test file.

## Tests

* New regression test file `tests/testthat/test-cleanup-v022.R`
  locks in: ensemble runs on default args; `compare_models()` runs on
  default args (single site, multiple sites, `return_all = TRUE`);
  `c4_fraction` round-trip from `invert_d2H()` to `invert_d2h()`
  produces consistent reconstructions; out-of-range `c4_fraction`
  is rejected at both wrapper entry points; `get_data_manifest()`
  returns `NULL` on download failure rather than a silently-empty list.

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
