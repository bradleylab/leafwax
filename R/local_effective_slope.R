# R/local_effective_slope.R - Per-draw d2H_wax<-d2H_precip slope at a
# specific site, with optional override and stationarity ceiling.
#
# Phase B of the v0.2.0 paleo-record workflow. Implements the local
# effective slope obligation from manuscript Section 4.5.5: a defensible
# slope must come from the model's site-specific posterior plus an
# explicit ceiling at alpha = 0.88, since the simple two-pool
# fractionation model cannot exceed that under stationarity of
# vegetation, leaf-water enrichment, seasonality, and source-water
# sampling.

#' Local effective slope at a paleo-reconstruction site
#'
#' Returns a per-draw vector of the d2H_wax-d2H_precip slope at a
#' single site, combining the global posterior beta_oipc with the
#' spatial slope GP prediction at that site. The result is the
#' quantity a paleohydrologist needs in Section 4.5.5 of the
#' manuscript: a site-specific slope posterior with an explicit
#' upper bound from simple-model fractionation theory.
#'
#' Three modes:
#' \itemize{
#'   \item Default: returns the model's per-draw slope at the site.
#'   \item Override (single value or per-draw vector) replaces the
#'     model slope with a defended local value (e.g., from independent
#'     evidence about source-water seasonality, leaf-water enrichment,
#'     or vegetation).
#'   \item Ceiling: any draw exceeding `ceiling` (default 0.88, the
#'     simple-model upper bound from `epsilon_app ~= -120 permil`) is
#'     truncated to the ceiling. A warning is emitted when more than
#'     5\% of draws are truncated, since that suggests the model and
#'     the user's intended interpretation are inconsistent with the
#'     simple-model bound.
#' }
#'
#' Pass the returned vector to `invert_d2H(..., slope = ...)` to
#' propagate it through the inversion.
#'
#' @param longitude Numeric, single longitude in decimal degrees.
#' @param latitude Numeric, single latitude in decimal degrees.
#' @param model_name Character, v10 model name (see
#'   `available_models()`). Must be a spatial model (`*_sp`) for the
#'   site-specific slope to differ from the global mean; non-spatial
#'   models return the global posterior unchanged.
#' @param override Optional numeric. NULL (default) uses the model
#'   slope. A single value broadcasts across all draws. A vector of
#'   length `n_draws` is used per draw.
#' @param ceiling Optional numeric upper bound on the slope. Default
#'   `0.88`, the simple-model ceiling under stationarity. Set to
#'   `Inf` or `NULL` to disable.
#' @param n_draws Integer, optional number of posterior draws to use
#'   (`NULL` uses all). Forwarded to `load_posteriors()`.
#' @param verbose Logical, whether to print progress messages.
#' @return Numeric vector of length `n_draws`, the per-draw effective
#'   slope at the site (after override and ceiling, in that order).
#' @export
#' @examples
#' \donttest{
#' # St. Louis with the baseline_sp model
#' s <- local_effective_slope(
#'   longitude = -90, latitude = 38,
#'   model_name = "baseline_sp",
#'   n_draws = 200
#' )
#' summary(s)
#'
#' # Override with a defended local slope
#' s_fixed <- local_effective_slope(
#'   longitude = -90, latitude = 38,
#'   model_name = "baseline_sp",
#'   override = 0.55, ceiling = 0.88
#' )
#'
#' # Pass through to the inversion. The slope vector and the
#' # inversion's posterior must use the same n_draws: pair
#' # local_effective_slope(..., n_draws = N) with
#' # invert_d2H(..., n_posterior_draws = N, slope = s), or pass a
#' # single point estimate (e.g., median(s)).
#' invert_d2H(d2H_wax = -180, d2H_wax_sd = 3,
#'            longitude = -90, latitude = 38,
#'            model_name = "baseline_sp",
#'            n_posterior_draws = 200,
#'            slope = s)
#' }
local_effective_slope <- function(longitude,
                                  latitude,
                                  model_name,
                                  override = NULL,
                                  ceiling = 0.88,
                                  n_draws = NULL,
                                  verbose = FALSE) {

  if (!is.numeric(longitude) || length(longitude) != 1L) {
    stop("longitude must be a single numeric value")
  }
  if (!is.numeric(latitude) || length(latitude) != 1L) {
    stop("latitude must be a single numeric value")
  }

  model <- load_posteriors(model_name, n_draws = n_draws, verbose = verbose)
  draws <- model$draws

  if (!"beta_oipc" %in% colnames(draws)) {
    stop("model '", model_name, "' has no beta_oipc parameter; ",
         "cannot extract a slope")
  }
  beta_oipc <- draws[["beta_oipc"]]
  n_iter    <- length(beta_oipc)

  # Site-specific slope perturbation from the spatial slope GP. For
  # non-spatial models the perturbation is identically zero.
  slope_pert <- numeric(n_iter)
  if (isTRUE(model$metadata$has_gp)) {
    if (is.null(model$spatial$knot_locs)) {
      stop("spatial model '", model_name, "' is missing knot_locs; ",
           "cannot predict a site-specific slope")
    }
    if (is.null(model$scaling)) {
      stop("model '", model_name, "' is missing scaling parameters; ",
           "cannot standardize coordinates for the GP prediction")
    }
    coords_new <- matrix(c(longitude, latitude), nrow = 1)
    dual <- predict_spatial_dual_gp(coords_new,
                                    model$spatial$knot_locs,
                                    draws,
                                    model$scaling)
    # dual$slope is n_draws x n_obs; take the only column.
    slope_pert <- as.numeric(dual$slope[, 1])
    if (length(slope_pert) != n_iter) {
      stop("internal: spatial slope perturbation length (",
           length(slope_pert), ") does not match beta_oipc length (",
           n_iter, ")")
    }
  }

  slope <- beta_oipc + slope_pert

  # Override applies AFTER the model slope is computed but BEFORE the
  # ceiling, so users overriding with a defended value still get the
  # ceiling applied unless they disable it.
  if (!is.null(override)) {
    if (!is.numeric(override)) {
      stop("override must be numeric")
    }
    if (length(override) == 1L) {
      slope <- rep(override, n_iter)
    } else if (length(override) == n_iter) {
      slope <- override
    } else {
      stop(sprintf(
        "override must be length 1 or length n_draws (%d), got %d",
        n_iter, length(override)
      ))
    }
  }

  # Ceiling truncation. Section 4.5.5 of the manuscript places the
  # simple-model upper bound at ~0.88 under stationarity of vegetation,
  # leaf-water enrichment, seasonal source-water sampling, and
  # evapotranspirative regime.
  if (!is.null(ceiling) && is.finite(ceiling)) {
    n_truncated <- sum(slope > ceiling)
    if (n_truncated > 0L) {
      slope <- pmin(slope, ceiling)
      frac_truncated <- n_truncated / n_iter
      if (verbose) {
        cat(sprintf(
          "  Truncated %d of %d draws (%.1f%%) at the ceiling = %.3g\n",
          n_truncated, n_iter, 100 * frac_truncated, ceiling
        ))
      }
      if (frac_truncated > 0.05) {
        warning(sprintf(
          paste("local_effective_slope(): %d of %d draws (%.1f%%) exceeded",
                "the ceiling = %.3g and were truncated. This is more than",
                "5%% and suggests the model's site-specific slope or",
                "your override is inconsistent with the simple-model",
                "stationarity bound from manuscript Section 4.5.5."),
          n_truncated, n_iter, 100 * frac_truncated, ceiling
        ), call. = FALSE)
      }
    }
  }

  slope
}
