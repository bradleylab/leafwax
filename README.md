# leafwax

<!-- badges: start -->
[![R-CMD-check](https://github.com/bradleylab/leafwax/actions/workflows/R-CMD-check.yaml/badge.svg?branch=master)](https://github.com/bradleylab/leafwax/actions/workflows/R-CMD-check.yaml)
[![DOI](https://zenodo.org/badge/DOI/10.5281/zenodo.20172571.svg)](https://doi.org/10.5281/zenodo.20172570)
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
without network access. The preview tier is for code-path
verification only — tail probabilities and 95% intervals are noisy
at 100 draws. **For inference, prefetch the full 1000-draw
posteriors explicitly:**

```r
# Required before any inferential use. Downloads from
# bradleylab/leafwax-data v1.0.1 and caches under
# tools::R_user_dir("leafwax", "data").
leafwax::download_model_data("baseline_sp")
```

Heavy posteriors come from
[`bradleylab/leafwax-data`](https://github.com/bradleylab/leafwax-data)
v1.0.1 (Zenodo DOI
[10.5281/zenodo.20085465](https://doi.org/10.5281/zenodo.20085465)).
Inversions done against the preview tier emit a loud warning
naming the function context and the actual draw count; set
`options(leafwax.suppress_preview_warning = TRUE)` to silence it
in batch jobs that have already acknowledged the limitation.

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

For a downcore series, the workflow combines four functions. The
calibration's posterior residual SD (σ<sub>residual</sub>, ≈16 per
mil for the spatial models) applies uniformly to absolute and
within-record use; see the manuscript Section 4.5.3 for the
derivation.

```r
library(leafwax)

# 1. Raw per-draw local slope at the site
slope <- local_effective_slope(
  longitude  = -90,
  latitude   = 38,
  model_name = "baseline_sp"
)

# 2. Inversion with the defended slope
recon <- invert_d2H(
  d2H_wax    = record$d2h_wax,
  d2H_wax_sd = record$d2h_wax_err,
  longitude  = rep(-90, nrow(record)),
  latitude   = rep( 38, nrow(record)),
  model_name = "baseline_sp",
  slope      = slope,
  record_id  = "your_record_id",
  return_full = TRUE
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
`_full*` variants carry it; the `elevation_*` variants do not. The
v10 fits did not produce `beta_elev` coefficients, so no model in
the table propagates supplied elevation through the predictor
linear combination — the historical "elevation_*" naming reflects
the regional context the variants were designed for, not a fitted
elevation effect.

Spatial models share a single 125-knot Fibonacci-sphere lattice.

## Manuscript correspondence

The paleo workflow maps directly to the manuscript:

| Manuscript section | Function |
|--------------------|----------|
| 4.5.3 detection threshold formula   | `detect_change()` |
| 4.5.5 local slope posterior         | `local_effective_slope()` |
| 4.5.6 four-level claim taxonomy     | `assess_claim()` |
| Section S4 inversion machinery      | `invert_d2H()` |

## Citation

Cite both the software archive and the related manuscript:

```bibtex
@software{bradley_leafwax_pkg_2026,
  author  = {Bradley, Alexander S.},
  title   = {leafwax: spatially-aware paleo-precipitation reconstruction
             from leaf-wax hydrogen isotopes},
  year    = {2026},
  doi     = {10.5281/zenodo.20172570},
  url     = {https://doi.org/10.5281/zenodo.20172570}
}

@unpublished{bradley_leafwax_paper_2026,
  author = {Bradley, Alexander S.},
  title  = {Spatial modeling improves the calibration of leaf wax
            hydrogen isotopes to precipitation},
  year   = {2026},
  note   = {Manuscript in preparation}
}
```

The `@software` DOI is the concept DOI — it always resolves to the
latest version. To cite a specific release, replace it with that
release's version DOI from the Zenodo deposit page.

## Help

* Function reference: `?invert_d2H`, `?local_effective_slope`,
  `?detect_change`, `?assess_claim`.
* Vignette: `vignette("paleo-record-workflow", package = "leafwax")`.
* Issues: <https://github.com/bradleylab/leafwax/issues>.

## License

MIT. See [LICENSE](LICENSE).
