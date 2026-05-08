# data-raw/regenerate_posteriors_light.R
#
# Regenerate inst/extdata/posteriors_light/ as a true 100-draw stratified
# subsample of the heavy posteriors at inst/extdata/posteriors/.
#
# The light tier ships with the package (CRAN-included) and is the
# default fallback when full posteriors are not available. It must be
# structurally complete — same column set as heavy, just fewer draws —
# so every code path that works on heavy also works on light. An
# earlier version of the light files dropped the per-knot
# z_intercept_spatial[*] / z_slope_spatial[*] columns, which broke
# spatial inversion under predict_spatial_dual_gp().
#
# Run from package root:
#   Rscript data-raw/regenerate_posteriors_light.R
#
# Output: ~1.5 MB total across 14 models, ~155 KB per spatial model
# and ~10-15 KB per non-spatial model.

suppressPackageStartupMessages({
  library(here)
})

heavy_dir <- here::here("inst", "extdata", "posteriors")
light_dir <- here::here("inst", "extdata", "posteriors_light")
n_keep <- 100L

stopifnot(dir.exists(heavy_dir))
if (!dir.exists(light_dir)) dir.create(light_dir, recursive = TRUE)

heavy_files <- list.files(heavy_dir,
                          pattern = "_posterior\\.rds$",
                          full.names = TRUE)
stopifnot(length(heavy_files) == 14L)

for (f in heavy_files) {
  draws <- readRDS(f)
  # Deterministic stratified thinning: evenly spaced indices across
  # the full posterior so two runs give identical light tiers.
  idx <- round(seq.int(1, nrow(draws), length.out = n_keep))
  light <- draws[idx, , drop = FALSE]

  out <- file.path(light_dir, basename(f))
  saveRDS(light, out, compress = "xz")
  sz <- file.size(out)
  message(sprintf("  %s: %d cols x %d draws -> %d KB",
                  basename(f), ncol(light), nrow(light),
                  round(sz / 1024)))
}

total <- sum(file.size(list.files(light_dir,
                                  pattern = "_posterior\\.rds$",
                                  full.names = TRUE)))
message(sprintf("\nTotal posteriors_light/: %d KB", round(total / 1024)))
