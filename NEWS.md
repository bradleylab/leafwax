# leafwax 0.4.0

* Replaced ratio inversion with a likelihood-based Bayesian inversion over
  paired calibration draws and a caller-specified reconstruction prior.
* Multi-row records jointly reweight shared calibration draws and return
  explicit diagnostics for prior influence, slope sign, numerical integration,
  mixture effective sample size, and saved-draw stability.
* Zero and negative slope draws are retained. Posterior samples require an
  explicit seed; the 100-draw preview tier cannot return inferential results.
* Reconstruction fails closed for calibration variants whose complete new-site
  predictor design is unavailable. Model ensembles require an explicit list of
  compatible models and have no default scientific composition.
* Public slope values now use physical units (per mil wax per per mil
  precipitation). `local_effective_slope()` back-transforms the fitted
  standardized coefficient, and `invert_d2H()` converts physical slope
  overrides back to fitted-model units internally. This also puts
  `detect_change()` thresholds on a consistent physical scale.

Posterior data and integrity update.

* Posteriors were re-fit in the 2026-07-28 chordal-distance calibration
  analysis (n = 1,128 calibration observations; Africa 142).
  All 14 model posteriors, the shipped 100-draw preview tier, and the
  spatial-model knot metadata were generated from this run.
* Three interaction models changed their coefficient set to match the
  fitted Stan specifications: `elevation_c4_interact_sp` carries the
  `beta_oipc_x_c4` interaction term (previously absent), while `full` and
  `full_sp` no longer carry `beta_oipc_x_c4` (retaining the plant-functional-type
  interactions `beta_oipc_x_grass`, `beta_oipc_x_shrub`, `beta_oipc_x_tree`).
* Complete posterior files are distributed in companion data release v3.0.0
  (doi:10.5281/zenodo.21880665).
  `download_model_data()` verifies both file size and SHA-256 against the
  immutable release manifest before a file enters the package cache.

# leafwax 0.2.7

CRAN compatibility updates.

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

# leafwax 0.2.6

Initial CRAN release.

## Features

* Bayesian inversion of leaf-wax δ²H to precipitation δ²H using
  spatially-aware hierarchical calibrations (14 model variants from
  Bradley 2026). Posteriors are pre-computed in Stan and
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
* A 100-draw preview posterior tier ships with the package; complete posterior
  files are distributed separately.
