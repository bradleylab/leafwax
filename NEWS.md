# leafwax 0.2.6

## Bug fixes

* `detect_change()` previously multiplied the entire combined-noise SD
  by `sqrt(2 * (1 - rho_t))`, which incorrectly applied the lag-1
  autocorrelation factor to the analytical-measurement-error term.
  The detection threshold now decomposes the variance of the
  difference between two single samples as
  `2 * sigma_residual^2 * (1 - rho_t) + 2 * sigma_analytical^2`,
  so the autocorrelation factor enters only the residual component.
  The previous formula understated the threshold in the high-`rho_t`
  regime. At `rho_t = 0` the two formulas coincide; at `rho_t = 0.5`
  and `rho_t = 0.8`, with `sigma_residual = 16`, `sigma_analytical
  = 3`, and `beta_eff = 0.55`, the corrected threshold rises from
  ~57 to ~59 per mil and from ~36 to ~39 per mil, respectively.
  The returned `formula$sigma_combined` is retained as a diagnostic
  but is no longer used in the threshold calculation.

* `assess_claim()` Level 1 carried the same conceptual error: the
  analytical-noise threshold was scaled by `sqrt(2 * (1 - rho_t))`
  even though analytical measurement error is independent between
  samples. The Level 1 threshold is now
  `z * sqrt(2) * sigma_analytical`, invariant to `rho_t`. Records
  that previously cleared Level 1 only by virtue of a high `rho_t`
  shrinking the threshold no longer clear it.

# leafwax 0.2.5

Initial CRAN release.

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
  through `invert_d2H()`.
* 100-draw preview posteriors ship with the package; full 1000-draw
  posteriors are downloaded from a versioned Zenodo deposit on first
  use (DOI: 10.5281/zenodo.20085465).
