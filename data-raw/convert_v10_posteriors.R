# data-raw/convert_v10_posteriors.R
#
# Converts v10 model fits (CmdStan output stored as posterior::draws_array)
# from the leafwax-spatial repo into leafwax-package-compatible
# posterior files (posterior::draws_df).
#
# Produces:
#   inst/extdata/posteriors/<model>_posterior.rds       (draws_df)
#   inst/extdata/spatial_metadata/<model>_knots.rds    (matrix; spatial models only)
#   inst/extdata/data_info.rds                         (lineage tag updated)
#
# Drops bulky non-inversion variables (mu, d2H_rep, log_lik) to keep
# package data small.
#
# Run from package root:
#   Rscript data-raw/convert_v10_posteriors.R
#
# Provenance:
#   v10 fits at <gca-working>/results/c2_run_20260501/<model>/posterior_draws.rds
#   Manuscript: bradleylab/leafwax-spatial commit 0621384 (May 2026)
#   125 knots; spherical Fibonacci lattice.

suppressPackageStartupMessages({
  library(posterior)
})

# --- Configuration ----------------------------------------------------------

V10_RESULTS_DIR <- "/Users/abradley/Desktop/proxy_uncertainty/leafwax_gca_working/results/c2_run_20260501"
PKG_ROOT        <- "/Users/abradley/Desktop/proxy_uncertainty/leafwax-pkg"
OUT_POST_DIR    <- file.path(PKG_ROOT, "inst", "extdata", "posteriors")
OUT_KNOT_DIR    <- file.path(PKG_ROOT, "inst", "extdata", "spatial_metadata")
N_KNOTS         <- 125  # confirmed canonical for v10
N_DRAWS_KEEP    <- 1000 # subsample draws for distribution; full ~12000 is overkill

MODELS <- c(
  "baseline", "baseline_env", "baseline_env_sp", "baseline_sp",
  "baseline_veg", "baseline_veg_sp", "c4_only_sp",
  "elevation_c4_interact_sp", "elevation_c4_sp", "elevation_only_sp",
  "full", "full_interact", "full_interact_sp", "full_sp"
)

# Variable families to DROP:
#   mu, d2H_rep, log_lik       — fitted values / posterior predictive / pointwise log-likelihood
#                                 (bulky, used only for diagnostics during fitting)
#   alpha_spatial              — unstandardized intercept random effect at each knot;
#                                 redundant with z_intercept_spatial * sigma_intercept_spatial
#   beta_oipc_spatial          — unstandardized slope random effect at each knot;
#                                 redundant with z_slope_spatial * sigma_slope_spatial
DROP_FAMILIES <- c("mu", "d2H_rep", "log_lik",
                   "alpha_spatial", "beta_oipc_spatial")

# --- Helpers ----------------------------------------------------------------

#' Extract family root from a parameter name like "beta_oipc_spatial[42]" -> "beta_oipc_spatial"
fam_of <- function(varnames) sub("[[].*$", "", varnames)

#' Generate spherical Fibonacci lattice of n_points (lon, lat) coordinates.
#' Mirrors leafwax::generate_fibonacci_sphere() exactly so loaded knots
#' match the predictive-process projection.
fibonacci_knots <- function(n_points = 125L) {
  golden_angle <- pi * (3.0 - sqrt(5.0))
  out <- matrix(NA_real_, n_points, 2)
  for (i in seq_len(n_points)) {
    theta  <- golden_angle * (i - 1)
    z      <- 1 - 2 * (i - 0.5) / n_points
    lat    <- asin(z) * 180 / pi
    lon    <- (theta %% (2 * pi)) * 180 / pi - 180
    out[i, ] <- c(lon, lat)
  }
  colnames(out) <- c("lon", "lat")
  out
}

#' Convert one v10 model's posterior to package format.
convert_one <- function(model, results_dir, out_post_dir, out_knot_dir,
                        n_knots = 125L, verbose = TRUE) {

  src <- file.path(results_dir, model, "posterior_draws.rds")
  if (!file.exists(src)) {
    cat(sprintf("  [SKIP] %s: posterior_draws.rds missing\n", model))
    return(invisible(NULL))
  }

  d <- readRDS(src)
  vars_in <- dimnames(d)[[3]]

  # Drop bulky families (mu, d2H_rep, log_lik). scale_weights[*] is small
  # and may be useful for diagnostics, so keep.
  fams <- fam_of(vars_in)
  keep_mask <- !(fams %in% DROP_FAMILIES)
  vars_keep <- vars_in[keep_mask]

  # Subset along the variable dimension
  d_sub <- d[ , , vars_keep, drop = FALSE]
  attributes(d_sub)$class <- class(d)  # preserve draws_array class

  # Convert to draws_df (rows = draws, cols = named parameters + .chain/.iter/.draw)
  ddf <- posterior::as_draws_df(d_sub)

  # Subsample draws for distribution.
  # Stratify by chain so each chain is represented evenly.
  if (!is.null(N_DRAWS_KEEP) && nrow(ddf) > N_DRAWS_KEEP) {
    chains <- unique(ddf$.chain)
    per_chain <- ceiling(N_DRAWS_KEEP / length(chains))
    set.seed(20260506L + as.integer(charToRaw(model)[1]))  # reproducible per model
    keep_idx <- unlist(lapply(chains, function(ch) {
      idx <- which(ddf$.chain == ch)
      sample(idx, min(per_chain, length(idx)))
    }))
    ddf <- ddf[sort(keep_idx)[seq_len(min(N_DRAWS_KEEP, length(keep_idx)))], , drop = FALSE]
    # Reset .draw to be sequential
    ddf$.draw <- seq_len(nrow(ddf))
  }

  # Save posterior file
  out_post <- file.path(out_post_dir, paste0(model, "_posterior.rds"))
  saveRDS(ddf, out_post, compress = "xz")

  is_spatial <- any(grepl("^z_intercept_spatial", vars_keep))

  if (is_spatial) {
    # Verify the knot count matches expectation
    n_knots_in_fit <- sum(grepl("^z_intercept_spatial\\[", vars_keep))
    if (n_knots_in_fit != n_knots) {
      cat(sprintf("  [WARN] %s: fit has %d knots, expected %d\n",
                  model, n_knots_in_fit, n_knots))
    }
    # Save knot coordinates (Fibonacci sphere; deterministic)
    knots <- fibonacci_knots(n_knots)
    out_knot <- file.path(out_knot_dir, paste0(model, "_knots.rds"))
    saveRDS(knots, out_knot, compress = "xz")
  }

  if (verbose) {
    cat(sprintf("  [OK]   %s: %d cols, %d draws, %s; %s\n",
                model,
                ncol(ddf) - 3L,  # subtract .chain/.iteration/.draw
                nrow(ddf),
                ifelse(is_spatial, "spatial", "non-spatial"),
                paste(round(file.info(out_post)$size / 1024, 1), "KB")))
  }
  invisible(out_post)
}

# --- Main -------------------------------------------------------------------

if (!dir.exists(V10_RESULTS_DIR)) {
  stop("v10 results directory not found: ", V10_RESULTS_DIR)
}
dir.create(OUT_POST_DIR, recursive = TRUE, showWarnings = FALSE)
dir.create(OUT_KNOT_DIR, recursive = TRUE, showWarnings = FALSE)

cat("Converting v10 posteriors -> leafwax format\n")
cat("Source: ", V10_RESULTS_DIR, "\n", sep = "")
cat("Source mtime: ",
    format(file.info(V10_RESULTS_DIR)$mtime, "%Y-%m-%d %H:%M:%S %Z"),
    "\n", sep = "")
cat("posterior_draws.rds files found: ",
    length(Sys.glob(file.path(V10_RESULTS_DIR, "*", "posterior_draws.rds"))),
    "\n", sep = "")
cat("Target: ", OUT_POST_DIR, "\n", sep = "")
cat(strrep("-", 70), "\n", sep = "")

for (m in MODELS) {
  convert_one(m, V10_RESULTS_DIR, OUT_POST_DIR, OUT_KNOT_DIR, N_KNOTS, TRUE)
}

# Update lineage marker
data_info <- list(
  posterior_lineage = "v10 (manuscript: bradleylab/leafwax-spatial @ 0621384)",
  fit_date          = "2026-05-01",
  n_obs_calibration = 1129L,
  n_knots_spatial   = N_KNOTS,
  conversion_date   = format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z"),
  variables_dropped = DROP_FAMILIES,
  draws_per_model   = N_DRAWS_KEEP
)
saveRDS(data_info, file.path(PKG_ROOT, "inst", "extdata", "data_info.rds"))

# Build spatial_models_metadata.{json,rds} consumed by package internals.
# Replaces the legacy 120-knot extract_spatial_metadata.R that used to live
# in R/ and auto-ran on devtools::load_all().
spatial_models <- c(
  "baseline_sp", "baseline_env_sp", "baseline_veg_sp",
  "c4_only_sp", "elevation_only_sp", "elevation_c4_sp",
  "elevation_c4_interact_sp", "full_sp", "full_interact_sp"
)

all_metadata <- list()
for (m in spatial_models) {
  post_file <- file.path(OUT_POST_DIR, paste0(m, "_posterior.rds"))
  if (!file.exists(post_file)) next
  draws <- readRDS(post_file)
  meta <- list(
    model_name      = m,
    n_draws         = nrow(draws),
    n_knots         = N_KNOTS,
    parameters      = colnames(draws),
    has_spatial     = TRUE,
    spatial_params  = grep("^(lambda|ls_|sigma_.*spatial|effective_scale)",
                           colnames(draws), value = TRUE)
  )
  if ("lambda_decay" %in% colnames(draws))
    meta$lambda_decay_range  <- range(draws[["lambda_decay"]])
  if ("effective_scale_km" %in% colnames(draws))
    meta$effective_scale_range <- range(draws[["effective_scale_km"]])
  if ("ls_intercept_km" %in% colnames(draws))
    meta$ls_intercept_range  <- range(draws[["ls_intercept_km"]])
  if ("ls_slope_km" %in% colnames(draws))
    meta$ls_slope_range      <- range(draws[["ls_slope_km"]])
  meta$coordinate_info <- list(
    note = "Coordinates standardized at runtime; knots in <model>_knots.rds",
    knot_coords_file = paste0(m, "_knots.rds")
  )
  all_metadata[[m]] <- meta
}

# JSON + RDS for downstream consumers
if (requireNamespace("jsonlite", quietly = TRUE)) {
  jsonlite::write_json(all_metadata,
                       file.path(OUT_KNOT_DIR, "spatial_models_metadata.json"),
                       pretty = TRUE, auto_unbox = TRUE)
}
saveRDS(all_metadata, file.path(OUT_KNOT_DIR, "spatial_models_metadata.rds"))
cat("Wrote spatial_models_metadata.{json,rds} with ", length(all_metadata),
    " spatial models.\n", sep = "")

cat(strrep("-", 70), "\n", sep = "")
cat("Done. Lineage tag written to inst/extdata/data_info.rds\n")
cat("Run smoke test: tests/testthat/test-v10-posteriors.R\n")
