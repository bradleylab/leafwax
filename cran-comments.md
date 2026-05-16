# cran-comments.md

## Test environments

- Local: macOS 26.0.1, R 4.4.1
- GitHub Actions R-CMD-check: macOS-latest, ubuntu-latest, windows-latest (R-release, R-devel, R-oldrel-1)

## R CMD check results

0 errors | 0 warnings | 3 notes

* This is a new submission.

Local `R CMD check --as-cran` also reported "unable to verify current
time" on this machine. No source files have future timestamps, and this
is not expected on CRAN's check infrastructure.

The third NOTE is "HTML version of manual" validation messages flagging
generated `<main>` elements and missing `<table>` summary attributes
across the auto-generated Rd-to-HTML output. These messages come from
the R Rd-to-HTML toolchain and the bundled HTML validator, not from
package-authored Rd markup; the same pattern appears on many recent
CRAN packages built under R 4.4+.

## Heavy data

`leafwax` ships a 100-draw posterior fixture under
`inst/extdata/posteriors_light/` so the package builds, tests, and
runs the vignette without network access. Full 1000-draw posteriors
(~14 MB total) are downloaded explicitly via
`download_model_data()` from `bradleylab/leafwax-data` v1.0.1
(Zenodo DOI 10.5281/zenodo.20085465) and cached under
`rappdirs::user_cache_dir("leafwax")`. The full-posterior download
is user-initiated and is not invoked during installation, examples,
tests, or vignette builds. The preview-tier fixture is intended only
for code-path verification; loading it triggers a warning at every
inferential layer.

## Reverse dependencies

This is a new submission; no reverse dependencies.
