# leafwax

<!-- badges: start -->
[![R-CMD-check](https://github.com/bradleylab/leafwax/actions/workflows/R-CMD-check.yaml/badge.svg?branch=master)](https://github.com/bradleylab/leafwax/actions/workflows/R-CMD-check.yaml)
<!-- badges: end -->

Bayesian inversion of leaf-wax hydrogen isotope ratios
(δ²H<sub>wax</sub>) to precipitation isotope values
(δ²H<sub>precip</sub>) and a defensibility framework for
paleoclimate claims based on those reconstructions.

`leafwax` is the operational backend for the manuscript "Spatial
modeling improves the calibration of leaf wax hydrogen isotopes to
precipitation" (Bradley, *Geochimica et Cosmochimica Acta*, submitted). It
exposes the 14 hierarchical Bayesian models reported there and the
four-phase paleo workflow that the manuscript references in
Sections 4.5.3, 4.5.5, and 4.5.6.

## Installation

```r
# install.packages("devtools")
devtools::install_github("bradleylab/leafwax")
```

The installed tarball ships a 100-draw "preview" fixture under
`inst/extdata/posteriors_light/` so the package builds and tests
without network access. Full 1000-draw posteriors are downloaded
on first use from
[`bradleylab/leafwax-data`](https://github.com/bradleylab/leafwax-data)
v1.0.1 (Zenodo concept DOI
[10.5281/zenodo.20085465](https://doi.org/10.5281/zenodo.20085465))
and cached under `tools::R_user_dir("leafwax", "data")`. Inversions
done against the preview tier emit a loud warning naming the
function context and the actual draw count; set
`options(leafwax.suppress_preview_warning = TRUE)` to silence it
in batch jobs that have already acknowledged the limitation.

```r
# Pre-fetch full posteriors (optional; download_model_data() is
# called automatically the first time load_posteriors() is asked
# for a model whose heavy posteriors are not cached locally)
leafwax::download_model_data("baseline_sp")
```

## Quick start: single-point inversion

```r
library(leafwax)

result <- invert_d2H(
  d2H_wax    = -180,
  d2H_wax_sd = 3,
  longitude  = -90,
  latitude   = 38,
  model_name = "baseline_sp"
)

result[, c("d2h_precip_mean", "d2h_precip_sd",
           "d2h_precip_lower", "d2h_precip_upper")]
```

`available_models()` lists the 14 v10 model variants. Spatial models
end in `_sp` and are recommended whenever site coordinates are known.

## Paleo-record workflow

For a downcore series, the workflow combines five functions:

```r
library(leafwax)

# 1. Within-record residual SD on a stationarity-defended interval
sw <- estimate_sigma_within(
  d2h_wax = record$d2h_wax,
  age     = record$age,
  baseline_interval = c(0, 5000),
  detrend = "linear",
  ar1_correction = TRUE
)

# 2. Per-draw local slope at the site, with the simple-model ceiling
slope <- local_effective_slope(
  longitude  = -90,
  latitude   = 38,
  model_name = "baseline_sp",
  ceiling    = 0.88
)

# 3. Inversion with within-record residual + defended slope
recon <- invert_d2H(
  d2H_wax    = record$d2h_wax,
  d2H_wax_sd = record$d2h_wax_err,
  longitude  = rep(-90, nrow(record)),
  latitude   = rep( 38, nrow(record)),
  model_name = "baseline_sp",
  sigma_within = sw$sigma_within,
  slope        = slope,
  record_id    = "your_record_id",
  return_full  = TRUE
)

# 4. Detection threshold + posterior P(change > magnitude)
rho_t <- estimate_temporal_autocorrelation(record$d2h_wax, record$age)
dc <- detect_change(
  reconstruction    = recon,
  age               = record$age,
  baseline_interval = c(0, 5000),
  test_intervals    = list(post = c(5000, 10000)),
  sigma_within      = sw$sigma_within,
  rho_t             = rho_t,
  beta_eff          = stats::median(slope),
  confidence        = 0.95,
  magnitudes        = c(10, 30, 50)
)

# 5. Four-level taxonomy verdict on a published claim
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

| Model | Spatial GP | Elevation | C4 | Vegetation | Interactions |
|-------|:----------:|:---------:|:--:|:----------:|:------------:|
| `baseline`                  |   |   |   |   |   |
| `baseline_sp`               | ✓ |   |   |   |   |
| `baseline_env`              |   | ✓ |   |   |   |
| `baseline_env_sp`           | ✓ | ✓ |   |   |   |
| `baseline_veg`              |   |   | ✓ | ✓ |   |
| `baseline_veg_sp`           | ✓ |   | ✓ | ✓ |   |
| `c4_only_sp`                | ✓ |   | ✓ |   |   |
| `elevation_only_sp`         | ✓ | ✓ |   |   |   |
| `elevation_c4_sp`           | ✓ | ✓ | ✓ |   |   |
| `elevation_c4_interact_sp`  | ✓ | ✓ | ✓ |   | ✓ |
| `full`                      |   |   | ✓ | ✓ | ✓ |
| `full_sp`                   | ✓ |   | ✓ | ✓ | ✓ |
| `full_interact`             |   |   | ✓ | ✓ | ✓ |
| `full_interact_sp`          | ✓ |   | ✓ | ✓ | ✓ |

Spatial models share a single 125-knot Fibonacci-sphere lattice.

## Manuscript correspondence

The paleo workflow maps directly to the manuscript:

| Manuscript section | Function |
|--------------------|----------|
| 4.5.3 σ<sub>within</sub> obligation | `estimate_sigma_within()` |
| 4.5.3 detection threshold formula   | `detect_change()` |
| 4.5.5 local slope ceiling           | `local_effective_slope(..., ceiling = 0.88)` |
| 4.5.6 four-level claim taxonomy     | `assess_claim()` |
| Section S4 inversion machinery      | `invert_d2H()` |

## Citation

```bibtex
@article{bradley_leafwax_2026,
  author  = {Bradley, Alexander S.},
  title   = {Spatial modeling improves the calibration of leaf wax
             hydrogen isotopes to precipitation},
  journal = {Geochimica et Cosmochimica Acta},
  year    = {2026}
}
```

## Help

* Function reference: `?invert_d2H`, `?estimate_sigma_within`,
  `?local_effective_slope`, `?detect_change`, `?assess_claim`.
* Vignette: `vignette("paleo-record-workflow", package = "leafwax")`.
* Issues: <https://github.com/bradleylab/leafwax/issues>.

## License

MIT. See [LICENSE](LICENSE).
