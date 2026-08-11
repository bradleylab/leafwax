# User-facing compatibility wrapper and capability helper. The Bayesian
# inversion implementation is in R/invert_d2h_bayesian.R.

#' @rdname invert_d2h
#' @param d2H_wax Numeric vector of leaf wax d2H values (per mil)
#' @param d2H_wax_sd Numeric vector of measurement uncertainties (per mil)
#' @param elevation_sd Elevation uncertainty (not used, kept for compatibility)
#' @param c4_fraction Numeric vector of C4 vegetation cover as a
#'   fraction in `[0, 1]`. The wrapper converts to the percent (0-100)
#'   scale used internally before standardisation.
#' @param c4_fraction_sd C4 fraction uncertainty (not used, kept for compatibility)
#' @param model_name Character string specifying which model to use
#' @param n_posterior_draws Integer number of posterior draws to use
#' @export
invert_d2H <- function(d2H_wax,
                       d2H_wax_sd = NULL,
                       longitude,
                       latitude,
                       elevation = NULL,
                       elevation_sd = 100,
                       c4_fraction = NULL,
                       c4_fraction_sd = 10,
                       pft_tree = NULL,
                       pft_shrub = NULL,
                       pft_grass = NULL,
                       model_name = "baseline",
                       n_posterior_draws = NULL,
                       return_full = FALSE,
                       credible_level = 0.9,
                       verbose = TRUE,
                       record_id = NULL,
                       slope = NULL,
                       prior = NULL,
                       n_inverse_samples = 0L,
                       seed = NULL,
                       grid_size = 2001L,
                       integration_tolerance = 1e-3,
                       tail_mass_tolerance = 1e-8,
                       draw_stability_tolerance = 2) {

  # The internal invert_d2h() core takes c4_percent (0-100), matching
  # the scale at which scaling_params$c4_mean / c4_sd were estimated.
  # The public wrapper takes c4_fraction (0-1) for consistency with
  # validate_inputs(), example_data, and the rest of the user-facing
  # API; convert here at the boundary.
  if (!is.null(c4_fraction)) {
    n_obs <- length(d2H_wax)
    if (length(c4_fraction) != n_obs) {
      stop(sprintf(
        "c4_fraction has length %d but d2H_wax has length %d; vector lengths must match.",
        length(c4_fraction), n_obs
      ))
    }
    if (any(c4_fraction < 0, na.rm = TRUE) ||
        any(c4_fraction > 1, na.rm = TRUE)) {
      stop("c4_fraction must be in [0, 1] (a fraction, not a percent). ",
           "Got values up to ", signif(max(c4_fraction, na.rm = TRUE), 3),
           ". If your inputs are on the 0-100 percent scale, divide by 100.")
    }
  }
  c4_percent_internal <- if (is.null(c4_fraction)) NULL else c4_fraction * 100

  invert_d2h(
    d2h_wax = d2H_wax,
    d2h_wax_err = d2H_wax_sd,
    longitude = longitude,
    latitude = latitude,
    elevation = elevation,
    c4_percent = c4_percent_internal,
    pft_tree = pft_tree,
    pft_shrub = pft_shrub,
    pft_grass = pft_grass,
    model_name = model_name,
    n_draws = n_posterior_draws,
    return_full = return_full,
    credible_level = credible_level,
    verbose = verbose,
    record_id = record_id,
    slope = slope,
    prior = prior,
    n_inverse_samples = n_inverse_samples,
    seed = seed,
    grid_size = grid_size,
    integration_tolerance = integration_tolerance,
    tail_mass_tolerance = tail_mass_tolerance,
    draw_stability_tolerance = draw_stability_tolerance
  )
}

#' Detect model capabilities from static metadata
#'
#' @param model_name Name of the model
#' @return List of capability flags
#' @export
detect_model_capabilities <- function(model_name) {
  caps <- get_model_parameters(model_name)$capabilities

  list(
    has_gp = caps$has_spatial,
    has_elevation = caps$has_elevation,
    has_precip = caps$has_precip,
    has_c4 = caps$has_c4,
    has_pft = caps$has_pft,
    has_interaction = caps$has_interaction
  )
}
