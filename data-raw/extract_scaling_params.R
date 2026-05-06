# data-raw/extract_scaling_params.R
#
# Pulls the standardization parameters used in v10 model fitting out of
# the leafwax-spatial _prepared_data/ directory and ships them as
# inst/extdata/scaling_params.rds so invert_d2H() can use them instead
# of placeholder defaults.
#
# All 14 model variants share an identical scaling_params list (verified
# 2026-05-06). lat/lon means + SDs are computed from the latitude/longitude
# arrays in stan_data because the v10 pipeline doesnt name them in
# scaling_params (it stores coord_scaling = c(lon_sd, lat_sd) only and
# subtracts the empirical means inline before kriging).
#
# Run from package root:
#   Rscript data-raw/extract_scaling_params.R

V10_PREPARED_DIR <- "/Users/abradley/Desktop/proxy_uncertainty/leafwax_gca_working/results/c2_run_20260501/_prepared_data"
PKG_ROOT         <- "/Users/abradley/Desktop/proxy_uncertainty/leafwax-pkg"
OUT_FILE         <- file.path(PKG_ROOT, "inst", "extdata", "scaling_params.rds")

ref_file <- file.path(V10_PREPARED_DIR, "stan_data_full_sp.rds")
if (!file.exists(ref_file)) {
  stop("v10 prepared-data reference file not found: ", ref_file)
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
fns <- list.files(V10_PREPARED_DIR, "^stan_data_.*[.]rds$", full.names = TRUE)
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
  source       = "v10 (manuscript: bradleylab/leafwax-spatial @ 0621384)",
  source_file  = ref_file,
  source_mtime = format(file.info(ref_file)$mtime, "%Y-%m-%d %H:%M:%S %Z"),
  extracted_on = format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z")
)

saveRDS(sp, OUT_FILE, compress = "xz")
cat("Wrote", OUT_FILE, "\n")
cat("Size:", round(file.info(OUT_FILE)$size / 1024, 2), "KB\n")
cat("\nFields shipped (", length(sp) - 1L, " standardization + lineage):\n", sep = "")
print(setdiff(names(sp), ".lineage"))
