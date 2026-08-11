# Per-draw d2H_wax<-d2H_precip slope at a specific site, with optional
# user override. Returns the posterior vector of the local slope in physical
# units (per mil wax per per mil precipitation)
# at the requested coordinates so downstream uncertainty propagation
# reflects the calibration's full inferential picture.
# The function does not clip, filter, or otherwise post-process the
# draws; mechanistic reasoning about plausible slope magnitudes
# belongs in the calibration's prior, not in a post-hoc filter.

#' Local effective slope at a paleo-reconstruction site
#'
#' Returns a per-draw vector of the local
#' \eqn{\beta_{\delta^2 H_p}}{beta_d2Hp} calibration slope at a single
#' site, combining the global precipitation-isotope slope with the spatial
#' slope GP prediction at that site. The fitted coefficient is converted from
#' standard deviations of wax per standard deviation of precipitation to
#' per mil wax per per mil precipitation. Every posterior draw is preserved;
#' only its units change.
#'
#' Two modes:
#' \itemize{
#'   \item Default: returns the model's per-draw slope at the site.
#'   \item Override (single value or per-draw vector) replaces the
#'     model slope with a defended local value (e.g., from independent
#'     evidence about source-water seasonality, leaf-water enrichment,
#'     or vegetation).
#' }
#'
#' The Bayesian inversion propagates its paired local-slope draws internally.
#' Pass this vector as `slope = ...` only when deliberately overriding that
#' internal calculation with a separately defended slope posterior.
#'
#' Mechanistic reference values (e.g. the simple two-pool stationarity
#' bound `alpha = 1 + epsilon_app/1000` ~ 0.88 under
#' `epsilon_app ~= -120 permil`; Sessions 2005) are documented for
#' interpretation but are never applied to the returned draws. The
#' frequency of draws above any chosen reference is computable
#' directly from the returned vector
#' (`mean(slope > 0.88)`) and carries scientific information about
#' how often the calibration implicates non-stationarity at the site.
#'
#' @param longitude Numeric, single longitude in decimal degrees.
#' @param latitude Numeric, single latitude in decimal degrees.
#' @param model_name Character, calibration model name (see
#'   `available_models()`). Must be a spatial model (`*_sp`) for the
#'   site-specific slope to differ from the global mean; non-spatial
#'   models return the global posterior unchanged.
#' @param override Optional numeric in per mil wax per per mil precipitation.
#'   NULL (default) uses the model
#'   slope. A single value broadcasts across all draws. A vector of
#'   length `n_draws` is used per draw.
#' @param n_draws Integer, optional number of posterior draws to use
#'   (`NULL` uses all). Forwarded to `load_posteriors()`.
#' @param verbose Logical, whether to print progress messages.
#' @return Numeric vector of length `n_draws`, the per-draw effective
#'   slope at the site in per mil wax per per mil precipitation (after
#'   override, if any).
#' @export
#' @examples
#' \dontrun{
#' local({
#'   old <- options(leafwax.suppress_preview_warning = TRUE)
#'   on.exit(options(old))
#'
#'   # St. Louis with the baseline_sp model
#'   s <- local_effective_slope(
#'     longitude = -90, latitude = 38,
#'     model_name = "baseline_sp",
#'     n_draws = 200
#'   )
#'   slope_summary <- summary(s)
#'
#'   # How often does the calibration imply a slope above the simple-model
#'   # stationarity bound at this site?
#'   fraction_above_bound <- mean(s > 0.88)
#'
#'   # Override with a defended local slope
#'   s_fixed <- local_effective_slope(
#'     longitude = -90, latitude = 38,
#'     model_name = "baseline_sp",
#'     override = 0.55
#'   )
#'
#'   # Pass through to the inversion. The slope vector and the
#'   # inversion's posterior must use the same n_draws: pair
#'   # local_effective_slope(..., n_draws = N) with
#'   # invert_d2H(..., n_posterior_draws = N, slope = s), or pass a
#'   # single point estimate (e.g., median(s)).
#'   result <- invert_d2H(d2H_wax = -180, d2H_wax_sd = 3,
#'                        longitude = -90, latitude = 38,
#'                        model_name = "baseline_sp",
#'                        n_posterior_draws = 200,
#'                        slope = s,
#'                        prior = d2h_prior_normal(-70, 30),
#'                        verbose = FALSE)
#' })
#' }
local_effective_slope <- function(longitude,
                                  latitude,
                                  model_name,
                                  override = NULL,
                                  n_draws = NULL,
                                  verbose = FALSE) {

  if (!is.numeric(longitude) || length(longitude) != 1L) {
    stop("longitude must be a single numeric value")
  }
  if (!is.numeric(latitude) || length(latitude) != 1L) {
    stop("latitude must be a single numeric value")
  }

  model <- load_posteriors(model_name, n_draws = n_draws, verbose = verbose)
  require_inference_tier(
    model$metadata$tier, model_name, "local_effective_slope()",
    nrow(model$draws)
  )
  draws <- model$draws

  if (!"beta_d2Hp" %in% colnames(draws)) {
    stop("model '", model_name, "' has no beta_d2Hp parameter; ",
         "cannot extract a slope")
  }
  beta_d2Hp <- draws[["beta_d2Hp"]]
  n_iter    <- length(beta_d2Hp)

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
                                    model$scaling,
                                    metric = model$metadata$spatial_metric)
    # dual$slope is n_draws x n_obs; take the only column.
    slope_pert <- as.numeric(dual$slope[, 1])
    if (length(slope_pert) != n_iter) {
      stop("internal: spatial slope perturbation length (",
           length(slope_pert), ") does not match beta_d2Hp length (",
           n_iter, ")")
    }
  }

  slope <- .model_slope_to_physical(
    beta_d2Hp + slope_pert,
    model$scaling
  )

  # Override replaces the model slope with a user-supplied value or
  # vector. The override is the user's decision; the package does not
  # post-process it further.
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

  slope
}
