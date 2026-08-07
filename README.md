# leafwax

<!-- badges: start -->
[![R-CMD-check](https://github.com/bradleylab/leafwax/actions/workflows/R-CMD-check.yaml/badge.svg?branch=master)](https://github.com/bradleylab/leafwax/actions/workflows/R-CMD-check.yaml)
<!-- badges: end -->

Bayesian inversion of leaf-wax hydrogen isotope ratios
(δ²H<sub>wax</sub>) to precipitation isotope values
(δ²H<sub>precip</sub>) and a defensibility framework for
paleoclimate claims based on those reconstructions.

`leafwax` is the development backend for the manuscript "Geography
limits the transferability of global leaf-wax isotope calibrations"
(Bradley, prepared for submission to *Communications
Earth & Environment*). It can inspect the 14 frozen hierarchical fits.
The validated Bayesian reconstruction interface currently supports the
`baseline`, `baseline_sp`, and `c4_only_sp` designs; other designs fail
closed because their complete new-site predictor basis is unavailable.

## Installation

No package-registry or archived release is claimed for this development
version. Install from the public source repository; release instructions and
accession identifiers will be added after final manuscript review.

The installed tarball ships a 100-draw "preview" fixture under
`inst/extdata/posteriors_light/` so the package builds and tests
without network access. The preview tier is for code-path
verification only — tail probabilities and 95% intervals are noisy
at 100 draws. Inferential inversion refuses this preview tier. Complete
frozen posteriors are required. The chordal-run files are publicly available in
[`bradleylab/leafwax-data`](https://github.com/bradleylab/leafwax-data), while
automatic download wiring remains disabled until the validated release.

## Quick start: single-point inversion

```r
library(leafwax)

result <- invert_d2H(
  d2H_wax    = -180,
  d2H_wax_sd = 3,
  longitude  = -90,
  latitude   = 38,
  model_name = "baseline_sp",
  prior      = d2h_prior_normal(mean = -70, sd = 30)
)

result$summary[, c("d2h_precip_median",
                   "d2h_precip_lower", "d2h_precip_upper")]
```

`available_models()` lists the 14 frozen calibration variants; this does not
mean that all 14 have a complete reconstruction design.

## Paleo-record workflow

For a downcore series, the workflow combines four functions. The
calibration's posterior residual SD (σ<sub>residual</sub>, ≈16 per
mil for the spatial models) applies uniformly to absolute and
within-record use; see the manuscript Methods subsection "Inversion and
detection thresholds" for the
derivation.

```r
library(leafwax)

# Example only: the prior must be justified for the record and sensitivity
# to alternative proper priors should be reported.
reconstruction_prior <- d2h_prior_normal(mean = -70, sd = 30)

# 1. Raw per-draw local slope at the site
slope <- local_effective_slope(
  longitude  = -90,
  latitude   = 38,
  model_name = "baseline_sp"
)

# 2. Inversion. Paired local-slope draws are propagated internally; the
# separate slope object is retained for diagnostics and the threshold below.
recon <- invert_d2H(
  d2H_wax    = record$d2h_wax,
  d2H_wax_sd = record$d2h_wax_err,
  longitude  = rep(-90, nrow(record)),
  latitude   = rep( 38, nrow(record)),
  model_name = "baseline_sp",
  record_id  = "your_record_id",
  prior      = reconstruction_prior,
  return_full = TRUE,
  n_inverse_samples = 4000,
  seed = 20260801
)

# 3. Detection threshold + posterior P(change > magnitude)
rho_t <- estimate_temporal_autocorrelation(record$d2h_wax, record$age)
dc <- detect_change(
  reconstruction    = recon,
  age               = record$age,
  baseline_interval = c(0, 5000),
  test_intervals    = list(post = c(5000, 10000)),
  sigma_residual    = 16,
  rho_t             = rho_t,
  beta_eff          = stats::median(slope),
  confidence        = 0.95,
  magnitudes        = c(10, 30, 50)
)

# 4. Four-level taxonomy verdict on a published claim
verdict <- assess_claim(
  record         = record,
  claim          = list(level = 4, ...),     # see ?assess_claim
  reconstruction = recon
)
verdict$highest_level
```

The full sequence on a real Iso2k record is in
`vignette("paleo-record-workflow", package = "leafwax")`.

## Available models

`available_models()` returns the 14 v10 variants. Capability flags
are derived from the posterior parameter names, not the model id, so
the routing layer correctly reflects what each fit actually contains.

| Model | Spatial GP | Precip | C4 | Vegetation | Interactions |
|-------|:----------:|:------:|:--:|:----------:|:------------:|
| `baseline`                  |   |   |   |   |   |
| `baseline_sp`               | x |   |   |   |   |
| `baseline_env`              |   | x |   |   |   |
| `baseline_env_sp`           | x | x |   |   |   |
| `baseline_veg`              |   |   | x | x |   |
| `baseline_veg_sp`           | x |   | x | x |   |
| `c4_only_sp`                | x |   | x |   |   |
| `elevation_only_sp`         | x |   |   |   |   |
| `elevation_c4_sp`           | x |   | x |   |   |
| `elevation_c4_interact_sp`  | x |   | x |   | x |
| `full`                      |   | x | x | x | x |
| `full_sp`                   | x | x | x | x | x |
| `full_interact`             |   | x | x | x | x |
| `full_interact_sp`          | x | x | x | x | x |

The "Precip" column flags models that include a fitted
precipitation-amount coefficient (`beta_precip`). The `_env` and
`_full*` variants carry it; the `elevation_*` variants do not. Nine chordal
fits include an elevation spline and the frozen deposits retain its
coefficients. Elevation is nevertheless not consumed by the current Bayesian
reconstruction designs because the complete new-site multiscale spline basis
is unavailable. This is a reconstruction-interface boundary, not a claim that
elevation was absent from the fitted calibration.

Spatial models share a single 125-knot Fibonacci-sphere lattice.

## Manuscript correspondence

The paleo workflow maps directly to the manuscript:

| Manuscript section | Function |
|--------------------|----------|
| Methods: Inversion and detection thresholds; Supplement S8.1.1 | `detect_change()` |
| Supplement S8.2 vegetation-only envelope | `compute_vegetation_envelope()` |
| Supplement S8.1 local slope and Bayesian inversion | `local_effective_slope()`, `invert_d2H()` |

`assess_claim()` provides an additional package-level claim-screening workflow;
the submitted manuscript does not present that four-level taxonomy.

## Citation

Release-specific citation metadata and persistent identifiers are pending
final validation. Do not cite this working tree as a released package.

## Help

* Function reference: `?invert_d2H`, `?local_effective_slope`,
  `?detect_change`, `?assess_claim`, `?compute_vegetation_envelope`.
* Vignette: `vignette("paleo-record-workflow", package = "leafwax")`.
* Issues: <https://github.com/bradleylab/leafwax/issues>.

## License

MIT. See [LICENSE](LICENSE).
