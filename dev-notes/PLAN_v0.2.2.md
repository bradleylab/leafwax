# leafwax v0.2.2 — spaghetti-audit cleanup plan

Goal: address findings A (real bugs), B (docs/naming drift), and C
(legacy v0.1 code drag) from the 2026-05-08 spaghetti audit. Defer D
(function decomposition) until after first CRAN submission.

This is the plan to land on top of the existing `cran-prep/lazy-load`
branch (PR #2 against master), bumping the package from 0.2.1 → 0.2.2.

## State as of plan write (2026-05-08)

- Branch: `cran-prep/lazy-load` at tip `cbbef54`. PR #2 open against
  master.
- 5 CRAN-prep commits already landed: lazy-load wiring, preview-tier
  warnings, polish (0.2.1, internal helpers), data_urls.json wired to
  Zenodo, codex-review fixups + bump to leafwax-data v1.0.1.
- `R CMD check --as-cran`: 0 ERR / 0 WARN / 275 PASS / 2 NOTEs (New
  submission + URL 404s gated on the public-repo flip).
- Heavy data archive at bradleylab/leafwax-data v1.0.1, Zenodo concept
  DOI 10.5281/zenodo.20085465 (auto-resolves to v1.0.1 record
  20086180).
- Spaghetti audit (3 Claude reviewers + R-aware deterministic checks
  + codex review of the plan) complete; codex caught 2 bugs the
  Claude reviewers missed.

## Two commits

Both land on the existing `cran-prep/lazy-load` branch.

### Commit 1 — mechanical CRAN-readiness sweep

Low-risk, mostly find-and-replace. Reviewable as a single readable diff.

**Doc/example fixes (replace v0.1 b0b1_* model names with v10 names):**

| File:line | Current | Replace with |
|---|---|---|
| `R/leafwax-package.R:72` | `model = "baseline"` (executable example; partial-matches via R's arg matching) | `model_name = "baseline"` |
| `R/api_functions.R:55` | example uses `b0b1_elev_sp` | `baseline_env_sp` |
| `R/api_functions.R:444` | default `model_name = "b0b1"` | `"baseline"` |
| `R/batch_processing.R:31` | example `b0b1_elev_sp` | `baseline_env_sp` |
| `R/batch_processing.R:267` | example list of v0.1 names | v10 equivalents |
| `R/data_loading.R:78` | example `b0b1_sp` | `baseline_sp` |
| `R/data_loading.R:359` | example `b0b1_sp` | `baseline_sp` |
| `R/download_data.R:21` | example `b0b1_sp` | `baseline_sp` |
| `R/download_data.R:24` | example `b0b1_elev` + `v1.0.0` | `baseline_env` + `v1.0.1` |
| `R/download_data.R:116` | example `b0b1_sp` | `baseline_sp` |
| `R/download_data.R:119` | example `b0b1_sp` + `v1.0.0` | `baseline_sp` + `v1.0.1` |
| `R/download_data.R:379` | example `b0b1_sp` | `baseline_sp` |
| `R/lookup_integration.R:92` | example `b0b1_sp` | `baseline_sp` |
| `R/lookup_tables.R:62` | example `b0b1_sp` | `baseline_sp` |
| `R/lookup_tables.R:218` | example `b0b1_sp` | `baseline_sp` |

**Other mechanical fixes:**

- `R/download_data.R:233`: qualify `curlGetHeaders` → `utils::curlGetHeaders`. (Not strictly required since `utils` is in Imports, but defensive against `warnPartialMatchArgs`.)
- `R/download_data.R:317`: replace `[YOUR-USERNAME]` placeholder URL fallback. Either delete the fallback (the JSON ships in extdata; missing == broken install) or substitute `bradleylab/leafwax-data/main`.
- `R/load_posteriors.R:1`: header says `# R/load_posteriors_simple.R - …`; file is `load_posteriors.R`. Delete the misleading line.
- `R/load_posteriors.R:141`: replace `(Codex P2 on Phase B)` review-history marker with content-only justification.
- `R/invert_d2h.R:509,534,596,619`: drop `Phase A` / `Phase B` / `(Phase A)` drafting-history labels; keep substantive content.
- `R/leafwax-package.R:49`: replace `Comprehensive model validation and recommendations` AI-slop with a specific capability or delete the bullet.
- `R/invert_d2h.R:341,378`: drop or cite the magic-default comments (`# Default 3 per mil uncertainty`, `# Global average`).
- `R/invert_d2h.R:500`: delete stale explanatory comment about code that no longer exists at that location.
- `README.md`: rewrite the section claiming the package ships ~10 MB of posteriors; describe the lazy-load architecture instead (light tier ships, full posteriors fetched via `download_model_data()` from the Zenodo-archived bradleylab/leafwax-data v1.0.1).
- `.Rbuildignore`: change `^PLAN_v0\.2\.0\.md$` to `^PLAN_v.*\.md$` to also exclude this PLAN.
- `DESCRIPTION`: bump Version 0.2.1 → 0.2.2.
- `NEWS.md`: prepend `# leafwax 0.2.2` section describing the cleanup.
- Run `roxygen2::roxygenise(".")` to regenerate Rd files (handles any param/example changes from above).

**Verification after commit 1:**

```bash
cd /Users/abradley/Desktop/proxy_uncertainty/leafwax-pkg
Rscript -e 'roxygen2::roxygenise(".")'
R CMD build .
R CMD check --as-cran --no-manual --run-donttest leafwax_0.2.2.tar.gz
```

Expected: same 2 NOTEs as today (New submission + URL 404s); 275 PASS. The unconditional URL example fix in `R/leafwax-package.R:72` and the `\dontrun{}` example fixes should not change check status, but the lib check should be cleaner.

Estimated cost: **~1.5 hours.**

### Commit 2 — runtime correctness (judgement required)

Higher risk. Touches the inferential code paths. Needs the c4 units decision before starting.

**Decision required from operator before starting:**

> **c4 vegetation cover units: fraction (0-1) or percentage (0-100)?**
>
> Current state of the codebase is split:
> - `validate_inputs()` uses `c4_fraction` (0-1).
> - `invert_d2h()` core treats `c4_percent` (0-100) — the parameter name says percent.
> - `predict_d2h_precip()` does `c4_percent = c4_fraction * 100` *unconditionally* with comment "Convert to percentage if needed" (one path is wrong).
> - `invert_d2H()` wrapper passes the user's `c4_fraction` straight through to `invert_d2h(c4_percent = ...)` without scaling.
> - `data.R` example_data has `c4_fraction` column with values in 0-1.
>
> **Recommendation:** standardize the public API on **fraction (0-1)** since that matches `validate_inputs`, the example data, and is more conventional in scientific R packages. Rename the internal `invert_d2h(c4_percent =)` arg to `c4_fraction =`, drop the *100 scaling everywhere, and document units explicitly. The fitted Stan models would need to know which scale they were fit at — verify by reading `data-raw/convert_v10_posteriors.R` and `inst/extdata/scaling_params.rds`.
>
> *If* the Stan models were fit with predictors on the 0-100 scale, the cleanest fix is the opposite: rename `c4_fraction` → `c4_percent` everywhere on the public API, and ensure all entry points apply the same input on the 0-100 scale that Stan saw.

Run this verification BEFORE deciding:

```r
sp <- readRDS("inst/extdata/scaling_params.rds")
str(sp)  # look for c4 mean/sd; if mean is ~0.2 and sd is ~0.3, fitting was on 0-1; if mean is ~25 and sd is ~30, fitting was on 0-100.
```

The decision determines which direction the rename goes. Most of the rest of this commit doesn't change.

**Delete v0.1 legacy functions outright:**

- `R/invert_d2h.R` lines 18-162: `load_model_posteriors`, `check_model_data`, `use_example_data`, `get_model_size_estimate`. The synthetic-data fallback in `use_example_data` is removed by this deletion.
- `R/data_loading.R` lines 125-225: `.download_model_data_v0_1`.
- Update `NAMESPACE`: remove `export(load_model_posteriors)` (will be auto-handled by roxygen since the `@export` tag goes away).
- Delete `man/load_model_posteriors.Rd` (auto-handled by roxygen).

**Fully fix `invert_d2H_ensemble()` (R/model_ensemble.R):**

- Line 14: change defaults from v0.1 (`b0b1_elev_c4_pft_sp`, etc.) to v10. Suggested defaults: `c("full_sp", "full_interact_sp", "elevation_c4_interact_sp")`.
- Line 20: replace `available_models()$model` with `available_models()` (the function returns a character vector, not a data frame).
- Line 33: add `return_full = TRUE` to the `invert_d2H()` call so the result has `posterior_draws`.
- Line 48: re-verify the `x$posterior_draws` access pattern works against the return shape; adjust if needed.
- Add a basic test in `tests/testthat/test-model-ensemble.R` to lock in correctness (current test count is 275; aim for ~280 after this commit).

**Fix `compare_models()` (R/batch_processing.R:286):**

- Update default `models =` list from v0.1 names to v10. Suggested default: a small subset like `c("baseline", "baseline_sp", "full_sp")` rather than all 14 (compare_models is meant for selection, not exhaustive comparison).
- Add a test for default-args invocation.

**Resolve c4 units (depends on decision):**

If decision is **fraction (0-1)**:

- `R/api_functions.R:182`: delete the `c4_percent = c4_fraction * 100` line; pass `c4_fraction` straight through.
- `R/invert_d2h.R`: rename `c4_percent` parameter to `c4_fraction` throughout the function body.
- `R/invert_d2h.R:711`: doc says "percentage (0-100)"; change to "fraction (0-1)".
- `R/invert_d2h.R:378`: default `c4_percent <- rep(25, n_obs)` becomes `c4_fraction <- rep(0.25, n_obs)`.
- Verify Stan scaling: if scaling_params shows c4 was fit on 0-1, no changes needed. If on 0-100, multiply by 100 before applying Stan parameters (in one place, internally).
- Add a regression test verifying `invert_d2H(c4_fraction = 0.5, ...)` and `invert_d2h(c4_fraction = 0.5, ...)` give identical results.

If decision is **percent (0-100)**: mirror image of the above.

**Make `get_data_manifest()` fail loudly (R/download_data.R:351):**

- Replace silent `tryCatch(error = function(e) return(list(files = list())))` with `tryCatch(error = function(e) {warning("Could not fetch data manifest: ", conditionMessage(e)); NULL})`.
- Update callers (e.g. `verify_data_integrity`) to handle `NULL` manifest as "verification skipped" rather than "no checksums available."

**Verification after commit 2:**

```bash
cd /Users/abradley/Desktop/proxy_uncertainty/leafwax-pkg
Rscript -e 'roxygen2::roxygenise(".")'
R CMD build .
R CMD check --as-cran --no-manual --run-donttest leafwax_0.2.2.tar.gz
```

Expected: same 2 NOTEs as today (New submission + URL 404s); ~280 PASS (275 existing + new ensemble/compare_models/c4-units regression tests).

Critical sanity check: `invert_d2H_ensemble()` and `compare_models()` should both run successfully on default args. This is the regression we are explicitly fixing.

```r
library(leafwax)
# These should both run without error after commit 2:
e <- invert_d2H_ensemble(d2H_wax = -150, longitude = -90, latitude = 38)
c <- compare_models(data.frame(d2h_wax = -150, longitude = -90, latitude = 38))
```

Estimated cost: **~3 hours.**

## What we are NOT doing (deferred to v0.3.0+)

Audit category D — function decomposition. Specifically:

- `invert_d2h()` is 433 lines / 18 args / mixed abstraction. Decomposing safely needs regression tests against the current stochastic output (4-6 hours per codex's calibration).
- `predict_d2h_precip()` is 161 lines / 17 args / mixed abstraction.
- `assess_claim()` is 323 lines (decompose along L1→L2→L3→L4 seams).
- `detect_change()` is 186 lines.
- `validate_inputs()` is 148 lines.
- 31 god functions total; the above 5 are the worst.

These are NOT bugs. They work. Decomposing before CRAN submission introduces new bug risk and delays submission. We re-evaluate after the package is on CRAN and one or two more refits have happened.

## Path to CRAN after commit 2

1. Push commits to `cran-prep/lazy-load` (PR #2 updates).
2. **Operator action: flip `bradleylab/leafwax` repo to public** via `gh repo edit bradleylab/leafwax --visibility public`. Hard-to-reverse; explicit operator confirmation required.
3. Final `R CMD check --as-cran` after the visibility flip — expected 1 NOTE only (New submission). The URL 404s clear once the repo is public.
4. Merge PR #2 to master.
5. Tag v0.2.2 and submit to CRAN via `devtools::submit_cran()` or the CRAN web form.

## Risk register

| Risk | Mitigation |
|---|---|
| c4 units decision is wrong (we pick 0-1 but Stan fit on 0-100) | Verify against `inst/extdata/scaling_params.rds` BEFORE starting commit 2. Add regression test asserting end-to-end inversion produces sensible numbers. |
| Deleting v0.1 functions breaks a downstream caller we didn't anticipate | Grep the entire codebase for calls to deleted symbols before removing. Document removal in NEWS.md so reverse-dependency users can adapt. |
| `invert_d2H_ensemble` rewrite changes ensemble semantics | Add the regression test BEFORE rewriting; the test locks in the current intended behaviour. |
| Stan model dependence on `c4_percent` vs `c4_fraction` not visible from R/ | Read `data-raw/convert_v10_posteriors.R` (which converts the raw v10 fits to package format); the original Stan model code lives in the `bradleylab/leafwax-spatial` repo (manuscript code), not this package. |

## Success criteria

- `R CMD check --as-cran`: 0 ERR / 0 WARN / 1-2 NOTEs (only "New submission" + maybe future-timestamps).
- 280+ tests PASS, 0 FAIL.
- `invert_d2H_ensemble()` and `compare_models()` run on default args.
- No exported function references a model name that doesn't exist.
- README accurately describes lazy-load architecture.
- All roxygen examples either run or are explicitly `\dontrun{}` for stated reasons.
