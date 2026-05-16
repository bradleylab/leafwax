# leafwax 0.2.6

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
  through `invert_d2H()`. The within-record detection threshold
  decomposes the variance of the difference between two single samples
  as `2 * sigma_residual^2 * (1 - rho_t) + 2 * sigma_analytical^2`,
  applying the lag-1 autocorrelation factor only to the residual term
  (analytical measurement error is independent between samples).
* 100-draw preview posteriors ship with the package; full 1000-draw
  posteriors are downloaded from a versioned Zenodo deposit on first
  use (DOI: 10.5281/zenodo.20085465).
