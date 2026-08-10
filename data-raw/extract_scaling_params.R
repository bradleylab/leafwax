# data-raw/extract_scaling_params.R
#
# Pulls the standardization parameters used in the reported chordal model fits
# from the analysis run's _prepared_data/ directory and ships them as
# inst/extdata/scaling_params.rds so invert_d2H() can use them instead
# of placeholder defaults.
#
# All 14 model variants share an identical scaling_params list. Latitude and
# longitude means and SDs are computed from the coordinate arrays in stan_data
# because the fitting pipeline does not name them in
# scaling_params (it stores coord_scaling = c(lon_sd, lat_sd) only and
# subtracts the empirical means inline before kriging).
#
# Run from package root:
#   LEAFWAX_RUN_DIR=<analysis-run>/model_output \
#     Rscript data-raw/extract_scaling_params.R

MODEL_RUN_DIR    <- Sys.getenv("LEAFWAX_RUN_DIR", unset = "")
PKG_ROOT         <- normalizePath(".", mustWork = TRUE)
if (!file.exists(file.path(PKG_ROOT, "DESCRIPTION"))) {
  stop("Run this script from the leafwax package root.")
}
if (!nzchar(MODEL_RUN_DIR)) {
  stop("Set LEAFWAX_RUN_DIR to the chordal analysis run's model_output directory.")
}
MODEL_RUN_DIR    <- normalizePath(MODEL_RUN_DIR, mustWork = FALSE)
PREPARED_DIR     <- file.path(MODEL_RUN_DIR, "_prepared_data")
OUT_FILE         <- file.path(PKG_ROOT, "inst", "extdata", "scaling_params.rds")

ref_file <- file.path(PREPARED_DIR, "stan_data_full_sp.rds")
if (!file.exists(ref_file)) {
  stop("Prepared-data reference file not found: ", ref_file)
}

ref <- readRDS(ref_file)
sp  <- ref$scaling_params

# Augment with lat/lon means and SDs (computed from the raw arrays in
# stan_data; match coord_scaling[1]/[2] to within float tolerance).
sp$lat_mean <- mean(ref$latitude)
sp$lat_sd  <- sd(ref$latitude)
sp$lon_mean <- mean(ref$longitude)
sp$lon_sd  <- sd(ref$longitude)

# Sanity check vs coord_scaling (they should be equal modulo float tolerance)
cs <- ref$coord_scaling
stopifnot(abs(sp$lon_sd - cs[1]) < 1e-6,
          abs(sp$lat_sd - cs[2]) < 1e-6)

# Cross-validate against all other stan_data files: scaling_params core
# should be identical, and lat/lon stats should match (same input data).
fns <- list.files(PREPARED_DIR, "^stan_data_.*[.]rds$", full.names = TRUE)
core_fields <- c("d2H_mean", "d2H_sd", "oipc_mean", "oipc_sd",
                 "elev_mean", "elev_sd", "c4_mean", "c4_sd",
                 "precip_mean", "precip_sd")
for (fn in fns) {
  other <- readRDS(fn)
  for (f in core_fields) {
    if (!isTRUE(all.equal(sp[[f]], other$scaling_params[[f]]))) {
      stop("scaling_params field '", f, "' differs in ", basename(fn))
    }
  }
}
cat("Cross-validated scaling_params across", length(fns), "stan_data files.\n")

# Add lineage tag
sp$.lineage <- list(
  source_run = basename(dirname(MODEL_RUN_DIR)),
  reference_file = basename(ref_file)
)

saveRDS(sp, OUT_FILE, compress = "xz")
cat("Wrote", OUT_FILE, "\n")
cat("Size:", round(file.info(OUT_FILE)$size / 1024, 2), "KB\n")
cat("\nFields shipped (", length(sp) - 1L, " standardization + lineage):\n", sep = "")
print(setdiff(names(sp), ".lineage"))
