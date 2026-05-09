# cran-comments.md

## Test environments

- Local: macOS 14, R 4.4.1
- GitHub Actions R-CMD-check: macOS-latest, ubuntu-latest, windows-latest (R-release, R-devel, R-oldrel-1)

## R CMD check results

0 errors | 0 warnings | 1 note

* This is a new submission.

## Heavy data

`leafwax` ships a 100-draw posterior fixture under
`inst/extdata/posteriors_light/` so the package builds, tests, and
runs the vignette without network access. Full 1000-draw posteriors
(~14 MB total) are downloaded explicitly via
`download_model_data()` from `bradleylab/leafwax-data` v1.0.1
(Zenodo concept DOI 10.5281/zenodo.20085465) and cached under
`tools::R_user_dir("leafwax", "data")`. The preview-tier fixture is
intended only for code-path verification; loading it triggers a
warning at every inferential layer.

## Reverse dependencies

This is a new submission; no reverse dependencies.
