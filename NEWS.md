# leafwax 0.3.0.9000

Development version; no public release is claimed.

* Replaced ratio inversion with a likelihood-based Bayesian inversion over
  paired calibration draws and a caller-specified proper prior.
* Multi-row records jointly reweight shared calibration draws and return
  explicit diagnostics for prior influence, slope sign, numerical integration,
  mixture effective sample size, and saved-draw stability.
* Zero and negative slope draws are retained. Posterior samples require an
  explicit seed; the 100-draw preview tier cannot return inferential results.
* Reconstruction fails closed for calibration variants whose complete new-site
  predictor design is unavailable. Model ensembles require an explicit list of
  compatible models and have no default scientific composition.

Posterior data update.

* Posteriors re-fit on the authoritative chordal analysis run
  `c2_run_20260728_chordal` (n = 1128 calibration observations; Africa 142).
  This supersedes the earlier v10 / n = 1129 lineage and the frozen
  great-circle comparison run. All 14 model posteriors, the shipped
  100-draw preview tier, and the spatial-model knot metadata were
  regenerated from the frozen run.
* Three interaction models changed their coefficient set to match the
  frozen Stan specifications: `elevation_c4_interact_sp` now carries the
  `beta_oipc_x_c4` interaction term (previously absent), while `full` and
  `full_sp` no longer carry `beta_oipc_x_c4` (retaining the plant-functional-type
  interactions `beta_oipc_x_grass`, `beta_oipc_x_shrub`, `beta_oipc_x_tree`).
* Public posterior and package releases are deferred until final validation.

# leafwax 0.2.7 (pre-release milestone)

Package-check and distribution-metadata polish; no CRAN release is claimed.

* Updated `DESCRIPTION` formatting for CRAN: software/service names are quoted
  as `'Stan'` and `'Zenodo'`, and the data-deposit reference now uses
  `Bradley (2026) <doi:10.5281/zenodo.20085465>`.
* Replaced `\dontrun{}` examples with executable `\donttest{}` or unwrapped
  examples, with temporary cache directories and quiet output where examples
  touch downloads or cache state.
* Added the missing return-value documentation for
  `print.leafwax_posterior()`.
* Converted the remaining unguarded ensemble progress output to `message()`.
* Updated package documentation for the precipitation-isotope calibration
  slope.

# leafwax 0.2.6 (pre-release milestone)

Initial package-completeness milestone; no CRAN release is claimed.

## Features

* Bayesian inversion of leaf-wax δ²H to precipitation δ²H using
  spatially-aware hierarchical calibrations (14 model variants from
  Bradley 2026, in prep). Posteriors are pre-computed in Stan and
  shipped as serialized draws, so prediction does not require Stan.
* Four-level claim taxonomy via `assess_claim()`: from analytical-noise
  thresholds (Level 1) through directional hydroclimate change (Level 2,
  via corroborating evidence OR the vegetation-only envelope from
  `compute_vegetation_envelope()`), quantitative magnitude (Level 3),
  and unique attribution to precipitation isotopes (Level 4).
* Per-record change detection (`detect_change()`) with
  autocorrelation-adjusted thresholds and full posterior propagation
  through `invert_d2H()`. The within-record detection threshold
  decomposes the variance of the difference between two single samples
  as `2 * sigma_residual^2 * (1 - rho_t) + 2 * sigma_analytical^2`,
  applying the lag-1 autocorrelation factor only to the residual term
  (analytical measurement error is independent between samples).
* A 100-draw preview posterior tier was prepared for package checks. The
  planned public full-posterior deposit was not released in this milestone.
