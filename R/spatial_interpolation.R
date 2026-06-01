# R/spatial_interpolation.R
#
# Modified Predictive Process (mPP) kriging from knot-level Gaussian-process
# draws to a new prediction site. The v10 leafwax-spatial model uses a
# Matern 3/2 covariance kernel, two independent GP fields (intercept and
# slope, sharing knot coordinates and length scale, but with separate
# sigma values), and standardized 2D coordinates (lon, lat divided by the
# calibration-set lon/lat means and SDs).

#' @importFrom stats dist
NULL

# --- Internal helpers -------------------------------------------------------

#' Matern 3/2 covariance: k(d) = sigma^2 * (1 + sqrt(3)*d/rho) * exp(-sqrt(3)*d/rho)
#' @param d numeric matrix or vector of Euclidean distances (in standardized units)
#' @param sigma marginal SD
#' @param rho length scale (in standardized units; SAME units as d)
#' @return covariance values matching shape of d
#' @noRd
matern32 <- function(d, sigma, rho) {
  scaled <- sqrt(3) * d / rho
  sigma^2 * (1 + scaled) * exp(-scaled)
}

#' Pairwise Euclidean distances between two coordinate matrices.
#' @param a matrix(n_a, 2)
#' @param b matrix(n_b, 2)
#' @return matrix(n_a, n_b)
#' @noRd
pair_distances <- function(a, b) {
  outer(seq_len(nrow(a)), seq_len(nrow(b)),
        FUN = function(i, j) sqrt((a[i, 1] - b[j, 1])^2 + (a[i, 2] - b[j, 2])^2))
}

#' Convert ls in km to standardized-coordinate units, matching the v10
#' Stan model's `coord_scale_km = mean(coord_scaling) * 111.0` formula.
#' @param ls_km numeric in km
#' @param scaling list with $lon_sd and $lat_sd (degrees)
#' @noRd
ls_km_to_std <- function(ls_km, scaling) {
  coord_scale_km <- mean(c(scaling$lon_sd, scaling$lat_sd)) * 111.0
  ls_km / coord_scale_km
}

#' Standardize a coord matrix using the scaling parameters.
#' @param coords matrix(n, 2) of (lon, lat) in degrees
#' @param scaling list with $lon_mean, $lon_sd, $lat_mean, $lat_sd
#' @noRd
standardize_coords <- function(coords, scaling) {
  if (is.null(dim(coords))) coords <- matrix(coords, ncol = 2, byrow = TRUE)
  cbind(
    (coords[, 1] - scaling$lon_mean) / scaling$lon_sd,
    (coords[, 2] - scaling$lat_mean) / scaling$lat_sd
  )
}

# --- Public API -------------------------------------------------------------

#' Predict an mPP Gaussian-process random effect at a new location
#'
#' Single-GP version. Used internally by `predict_spatial_dual_gp()` for
#' each of the two (intercept, slope) fields. Matches the Matern 3/2 kernel
#' and standardized-coordinate convention from the v10 Stan model.
#'
#' @param coords_new matrix(n_obs, 2) of (lon, lat) in DEGREES.
#' @param knot_coords matrix(n_knots, 2) of (lon, lat) in DEGREES.
#' @param z_knots matrix(n_draws, n_knots) of standardized knot effects
#'   (e.g. `z_intercept_spatial[1..125]` from the posterior).
#' @param sigma_draws numeric(n_draws), the GP marginal SD.
#' @param ls_km_draws numeric(n_draws), the GP length scale in km
#'   (e.g. `ls_intercept_km`).
#' @param scaling list with `lon_mean`, `lon_sd`, `lat_mean`, `lat_sd`.
#' @param jitter ridge added to K_knots for numerical stability.
#' @return matrix(n_draws, n_obs) of predicted GP values at the new sites.
#' @keywords internal
predict_one_gp_mpp <- function(coords_new, knot_coords, z_knots,
                               sigma_draws, ls_km_draws, scaling,
                               jitter = 1e-4) {

  if (is.null(dim(coords_new)))   coords_new   <- matrix(coords_new,   ncol = 2, byrow = TRUE)
  if (is.null(dim(knot_coords)))  knot_coords  <- matrix(knot_coords,  ncol = 2, byrow = TRUE)

  coords_std <- standardize_coords(coords_new,  scaling)
  knot_std   <- standardize_coords(knot_coords, scaling)

  n_draws  <- nrow(z_knots)
  n_obs    <- nrow(coords_std)
  n_knots  <- nrow(knot_std)

  if (ncol(z_knots) != n_knots) {
    stop(sprintf("z_knots has %d columns but knot_coords has %d rows; mismatch.",
                 ncol(z_knots), n_knots))
  }

  knot_dists  <- pair_distances(knot_std, knot_std)
  cross_dists <- pair_distances(coords_std, knot_std)

  # The v10 Stan model computes K_knots = matern32(coords, alpha=1, rho=ls)
  # and applies sigma to knot effects post-kriging:
  #   knot_eff = sigma * z
  #   alpha_spatial += K_cross * solve(K_knots, knot_eff)
  # Mirror that exactly: kernel uses alpha = 1; sigma scales the prediction.
  pred <- matrix(0, n_draws, n_obs)
  for (i in seq_len(n_draws)) {
    ls_std  <- ls_km_to_std(ls_km_draws[i], scaling)
    sigma_i <- sigma_draws[i]
    K_knots <- matern32(knot_dists,  1.0, ls_std)
    K_cross <- matern32(cross_dists, 1.0, ls_std)
    diag(K_knots) <- diag(K_knots) + jitter
    knot_eff <- sigma_i * z_knots[i, ]
    pred[i, ] <- as.vector(K_cross %*% solve(K_knots, knot_eff))
  }
  pred
}

#' Predict both spatial intercept and spatial slope at new locations
#'
#' v10 carries two independent GPs. Both share knot coordinates and a
#' single length scale parameter (`ls_intercept_km == ls_slope_km` in
#' v10's posterior, two names for the same draw), but have distinct
#' `sigma_intercept_spatial` and `sigma_slope_spatial`, and distinct
#' `z_intercept_spatial[*]` and `z_slope_spatial[*]` knot effects.
#'
#' @param coords_new matrix(n_obs, 2) of (lon, lat) in DEGREES.
#' @param knot_coords matrix(n_knots, 2) of (lon, lat) in DEGREES.
#' @param draws data.frame of posterior draws (subset of
#'   leafwax_posterior$draws). Must contain columns
#'   `z_intercept_spatial[1..n_knots]`, `z_slope_spatial[1..n_knots]`,
#'   `sigma_intercept_spatial`, `sigma_slope_spatial`,
#'   and one of `ls_intercept_km` / `ls_slope_km`.
#' @param scaling list with `lon_mean`, `lon_sd`, `lat_mean`, `lat_sd`.
#' @return list with two matrices, each n_draws x n_obs:
#'   `intercept` (additive contribution to beta_0 in standardized
#'   d2H_wax space) and `slope` (additive contribution to the local
#'   \eqn{\beta_{\delta^2 H_p}}{beta_d2Hp} slope).
#' @keywords internal
#' @export
predict_spatial_dual_gp <- function(coords_new, knot_coords, draws, scaling) {

  z_int_cols   <- grep("^z_intercept_spatial\\[", colnames(draws), value = TRUE)
  z_slope_cols <- grep("^z_slope_spatial\\[",     colnames(draws), value = TRUE)
  if (!length(z_int_cols) || !length(z_slope_cols)) {
    stop("draws must contain z_intercept_spatial[*] and z_slope_spatial[*] columns.")
  }
  if (length(z_int_cols) != length(z_slope_cols)) {
    stop("z_intercept_spatial and z_slope_spatial have different knot counts.")
  }

  z_int   <- as.matrix(draws[, z_int_cols,   drop = FALSE])
  z_slope <- as.matrix(draws[, z_slope_cols, drop = FALSE])

  if (!"sigma_intercept_spatial" %in% colnames(draws)) {
    stop("draws missing sigma_intercept_spatial.")
  }
  if (!"sigma_slope_spatial" %in% colnames(draws)) {
    stop("draws missing sigma_slope_spatial.")
  }
  ls_col <- if ("ls_intercept_km" %in% colnames(draws)) "ls_intercept_km" else "ls_slope_km"
  if (!ls_col %in% colnames(draws)) {
    stop("draws missing both ls_intercept_km and ls_slope_km.")
  }

  # IMPORTANT — sigma_intercept_spatial in the posterior is
  # sigma_intercept_raw * d2H_wax_sd_original (a permil-readable
  # de-standardization that the Stan generated-quantities block emits).
  # For prediction in standardized response space we need the raw value,
  # i.e. sigma_intercept_spatial / d2H_sd. sigma_slope_spatial in the
  # posterior is already the raw value (no scaling factor).
  if (is.null(scaling$d2H_sd)) {
    stop("scaling$d2H_sd missing; cannot de-standardize sigma_intercept_spatial.")
  }
  sigma_int_raw   <- draws[["sigma_intercept_spatial"]] / scaling$d2H_sd
  sigma_slope_raw <- draws[["sigma_slope_spatial"]]

  list(
    intercept = predict_one_gp_mpp(coords_new, knot_coords, z_int,
                                   sigma_int_raw,
                                   draws[[ls_col]], scaling),
    slope     = predict_one_gp_mpp(coords_new, knot_coords, z_slope,
                                   sigma_slope_raw,
                                   draws[[ls_col]], scaling)
  )
}
