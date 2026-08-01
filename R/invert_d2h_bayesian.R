# Public Bayesian inversion built on the frozen calibration posterior.

.supported_bayesian_inverse_models <- c(
  "baseline",
  "baseline_sp",
  "c4_only_sp"
)

.validate_inverse_observations <- function(d2h_wax, d2h_wax_err,
                                           longitude, latitude) {
  n_obs <- length(d2h_wax)
  if (!n_obs || any(!is.finite(d2h_wax))) {
    stop("d2h_wax must be a non-empty finite numeric vector.", call. = FALSE)
  }
  if (length(d2h_wax_err) != n_obs || any(!is.finite(d2h_wax_err)) ||
      any(d2h_wax_err < 0)) {
    stop("d2h_wax_err must be non-negative and match d2h_wax.",
         call. = FALSE)
  }
  if (length(longitude) != n_obs || length(latitude) != n_obs ||
      any(!is.finite(longitude)) || any(!is.finite(latitude))) {
    stop("longitude and latitude must be finite and match d2h_wax.",
         call. = FALSE)
  }
  n_obs
}

.validate_inverse_record <- function(record_id, longitude, latitude, n_obs) {
  if (is.null(record_id)) {
    if (n_obs > 1L) {
      stop(
        "record_id is required when jointly inverting more than one row. ",
        "Call separately for unrelated sites or provide one shared record_id ",
        "for a same-site record.",
        call. = FALSE
      )
    }
    return(NULL)
  }
  record_id <- if (length(record_id) == 1L) rep(record_id, n_obs) else record_id
  if (length(record_id) != n_obs || length(unique(record_id)) != 1L) {
    stop("record_id must identify one record and have length one or length(d2h_wax).",
         call. = FALSE)
  }
  if (length(unique(longitude)) != 1L || length(unique(latitude)) != 1L) {
    stop("All samples in one record_id must share longitude and latitude.",
         call. = FALSE)
  }
  record_id
}

.prepare_inverse_components <- function(model, longitude, latitude,
                                        c4_percent, slope_override) {
  draws <- model$draws
  n_iter <- nrow(draws)
  n_obs <- length(longitude)
  base_params <- model$get_base_params()
  intercept <- matrix(
    as.numeric(base_params$beta_0), nrow = n_iter, ncol = n_obs
  )
  slope <- matrix(
    as.numeric(base_params$beta_d2Hp), nrow = n_iter, ncol = n_obs
  )

  if (model$metadata$has_gp) {
    if (is.null(model$spatial$knot_locs)) {
      stop("Spatial model has no knot locations; inversion cannot proceed.",
           call. = FALSE)
    }
    spatial <- predict_spatial_dual_gp(
      cbind(longitude, latitude),
      model$spatial$knot_locs,
      draws,
      model$scaling,
      metric = model$metadata$spatial_metric
    )
    intercept <- intercept + spatial$intercept
    slope <- slope + spatial$slope
  }

  if (identical(model$metadata$model_name, "c4_only_sp")) {
    if (is.null(c4_percent)) {
      stop("c4_percent (or c4_fraction through invert_d2H) is required for c4_only_sp.",
           call. = FALSE)
    }
    if (length(c4_percent) != n_obs || any(!is.finite(c4_percent)) ||
        any(c4_percent < 0) || any(c4_percent > 100)) {
      stop("c4_percent must be finite, in [0, 100], and match d2h_wax.",
           call. = FALSE)
    }
    vegetation <- model$get_vegetation_params()
    c4_standardized <- (
      c4_percent - model$scaling$c4_mean
    ) / model$scaling$c4_sd
    intercept <- intercept + outer(
      as.numeric(vegetation$beta_c4), c4_standardized
    )
  }

  if (!is.null(slope_override)) {
    if (!is.numeric(slope_override) || any(!is.finite(slope_override))) {
      stop("slope must contain finite numeric calibration-scale values.",
           call. = FALSE)
    }
    if (length(slope_override) == 1L) {
      slope <- matrix(slope_override, nrow = n_iter, ncol = n_obs)
    } else if (length(slope_override) == n_iter) {
      slope <- matrix(slope_override, nrow = n_iter, ncol = n_obs)
    } else {
      stop(
        "slope must have length one or match the retained calibration draws.",
        call. = FALSE
      )
    }
  }

  list(
    intercept_standardized = intercept,
    slope_standardized = slope,
    residual_sd_standardized = as.numeric(base_params$sigma)
  )
}

.run_inverse_from_components <- function(d2h_wax, d2h_wax_err, components,
                                         scaling, prior, credible_level,
                                         grid_size, integration_tolerance,
                                         tail_mass_tolerance, n_samples,
                                         seed) {
  slope_original <- components$slope_standardized / scaling$oipc_sd
  intercept_original <- components$intercept_standardized -
    components$slope_standardized * scaling$oipc_mean / scaling$oipc_sd
  response_standardized <- (d2h_wax - scaling$d2H_mean) / scaling$d2H_sd
  analytical_standardized <- d2h_wax_err / scaling$d2H_sd

  bayesian_record_inverse(
    y = response_standardized,
    intercept = intercept_original,
    slope = slope_original,
    residual_sd = components$residual_sd_standardized,
    analytical_sd = analytical_standardized,
    prior = prior,
    credible_level = credible_level,
    grid_size = grid_size,
    integration_tolerance = integration_tolerance,
    tail_mass_tolerance = tail_mass_tolerance,
    n_samples = n_samples,
    seed = seed
  )
}

.add_inverse_context <- function(result, d2h_wax, d2h_wax_err, longitude,
                                 latitude, elevation, model, record_id,
                                 stability, return_full) {
  result$summary <- data.frame(
    longitude = longitude,
    latitude = latitude,
    elevation = elevation,
    d2h_wax = d2h_wax,
    d2h_wax_err = d2h_wax_err,
    d2h_precip_mean = result$summary$mean,
    d2h_precip_median = result$summary$median,
    d2h_precip_sd = result$summary$sd,
    d2h_precip_lower = result$summary$lower,
    d2h_precip_upper = result$summary$upper,
    prediction_interval_width = result$summary$upper - result$summary$lower,
    row.names = NULL
  )
  result$diagnostics$draw_bank_stability <- stability
  if (!isTRUE(stability$within_tolerance) || result$status != "ok") {
    result$status <- "inconclusive"
  }
  result$model_info <- list(
    model_name = model$metadata$model_name,
    n_calibration_draws = nrow(model$draws),
    posterior_tier = model$metadata$tier,
    spatial_metric = model$metadata$spatial_metric,
    record_id = if (is.null(record_id)) NULL else record_id[[1L]],
    reconstruction_target = "latent precipitation d2H",
    calibration_reweighting = "joint across all rows"
  )
  result$metadata$return_full_requested <- isTRUE(return_full)
  attr(result, "leafwax_tier") <- model$metadata$tier
  result
}

#' Bayesian inversion of leaf-wax d2H to precipitation d2H
#'
#' Performs a likelihood-times-prior inversion over paired calibration
#' posterior draws. No division by a sampled slope, clipping, or post-hoc draw
#' removal is used. Multiple rows jointly reweight the shared calibration draw.
#'
#' @param d2h_wax Numeric vector of observed leaf-wax isotope values in per mil.
#' @param d2h_wax_err Non-negative analytical standard deviations in per mil.
#' @param longitude,latitude Numeric site coordinates in decimal degrees.
#' @param elevation Optional elevations retained in the output but not consumed
#'   by the currently supported inversion designs.
#' @param c4_percent C4 cover on a 0--100 scale, required by `c4_only_sp`.
#' @param pft_tree,pft_shrub,pft_grass Unsupported PFT inputs; supplying any
#'   currently fails closed.
#' @param model_name One of `baseline`, `baseline_sp`, or `c4_only_sp`.
#' @param n_draws Optional deterministic thinning count for paired calibration
#'   posterior draws.
#' @param return_full Whether to return joint posterior samples.
#' @param credible_level Central credible interval probability.
#' @param verbose Whether to report loading and diagnostic status.
#' @param record_id Identifier for a single shared-site record. Optional for a
#'   one-row inversion and required when `length(d2h_wax) > 1`.
#' @param slope Optional scalar or paired-draw override on the standardized
#'   calibration slope. Zero and negative values are retained.
#' @param prior Required proper precipitation-isotope prior from a
#'   `d2h_prior_*()` constructor, or one prior per row.
#' @param n_inverse_samples Number of joint inverse-posterior samples. Required
#'   to be positive when `return_full = TRUE`; otherwise it must be zero.
#' @param seed Explicit integer seed required for inverse-posterior samples.
#' @param grid_size Numerical integration grid size.
#' @param integration_tolerance Maximum permitted nested-grid summary change.
#' @param tail_mass_tolerance Maximum permitted unbounded-prior edge mass.
#' @param draw_stability_tolerance Maximum permitted summary change when the
#'   paired calibration draw bank is reduced to a deterministic nested half.
#' @return A `leafwax_inverse` object. Its `status` is `"inconclusive"` if
#'   numerical or saved-draw stability tolerances fail. Posterior samples are
#'   present only when explicitly requested with a seed.
#' @export
invert_d2h <- function(
    d2h_wax,
    d2h_wax_err = NULL,
    longitude,
    latitude,
    elevation = NULL,
    c4_percent = NULL,
    pft_tree = NULL,
    pft_shrub = NULL,
    pft_grass = NULL,
    model_name = "baseline",
    n_draws = NULL,
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
  if (!inherits(prior, "leafwax_d2h_prior") &&
      !(is.list(prior) && length(prior) == length(d2h_wax) &&
        all(vapply(prior, inherits, logical(1), "leafwax_d2h_prior")))) {
    stop("prior is required and must be a leafwax_d2h_prior (or one per row).",
         call. = FALSE)
  }
  if (!model_name %in% .supported_bayesian_inverse_models) {
    stop(
      "Bayesian inversion currently supports only: ",
      paste(.supported_bayesian_inverse_models, collapse = ", "),
      ". Models with precipitation/elevation covariates or isotope interactions ",
      "are refused because their complete reconstruction design is unavailable.",
      call. = FALSE
    )
  }
  n_inverse_samples <- as.integer(n_inverse_samples)
  if (isTRUE(return_full) && n_inverse_samples <= 0L) {
    stop("return_full = TRUE requires positive n_inverse_samples and an explicit seed.",
         call. = FALSE)
  }
  if (!isTRUE(return_full) && n_inverse_samples != 0L) {
    stop("Set return_full = TRUE when requesting inverse posterior samples.",
         call. = FALSE)
  }
  if (n_inverse_samples > 0L && is.null(seed)) {
    stop("An explicit seed is required for inverse posterior samples.",
         call. = FALSE)
  }
  if (!is.numeric(draw_stability_tolerance) ||
      length(draw_stability_tolerance) != 1L ||
      !is.finite(draw_stability_tolerance) || draw_stability_tolerance <= 0) {
    stop("draw_stability_tolerance must be positive and finite.",
         call. = FALSE)
  }

  if (is.null(d2h_wax_err)) {
    d2h_wax_err <- rep(DEFAULT_WAX_ERR_PERMIL, length(d2h_wax))
    if (verbose) {
      message("Using documented package analytical uncertainty: ",
              DEFAULT_WAX_ERR_PERMIL, " per mil.")
    }
  }
  n_obs <- .validate_inverse_observations(
    d2h_wax, d2h_wax_err, longitude, latitude
  )
  record_id <- .validate_inverse_record(
    record_id, longitude, latitude, n_obs
  )
  if (is.null(elevation)) {
    elevation <- rep(NA_real_, n_obs)
  } else if (length(elevation) != n_obs) {
    stop("elevation must be NULL or match d2h_wax.", call. = FALSE)
  }
  if (!is.null(pft_tree) || !is.null(pft_shrub) || !is.null(pft_grass)) {
    stop("PFT covariates are not consumed by the currently supported inversions.",
         call. = FALSE)
  }

  if (verbose) {
    message("Loading frozen calibration posterior: ", model_name)
  }
  model <- suppressWarnings(load_posteriors(
    model_name, n_draws = n_draws, verbose = FALSE
  ))
  require_inference_tier(
    model$metadata$tier, model_name, "invert_d2H()", nrow(model$draws)
  )
  if (is.null(model$scaling)) {
    stop("The fitted scaling parameters are required; placeholder scaling is refused.",
         call. = FALSE)
  }

  components <- .prepare_inverse_components(
    model, longitude, latitude, c4_percent, slope
  )
  result <- .run_inverse_from_components(
    d2h_wax, d2h_wax_err, components, model$scaling, prior,
    credible_level, grid_size, integration_tolerance,
    tail_mass_tolerance, n_inverse_samples, seed
  )

  nested_indices <- unique(round(seq.int(
    1L, nrow(model$draws), length.out = max(2L, floor(nrow(model$draws) / 2L))
  )))
  nested_components <- lapply(components, function(value) {
    if (is.matrix(value)) value[nested_indices, , drop = FALSE] else
      value[nested_indices]
  })
  nested <- .run_inverse_from_components(
    d2h_wax, d2h_wax_err, nested_components, model$scaling, prior,
    credible_level, grid_size, integration_tolerance,
    tail_mass_tolerance, 0L, NULL
  )
  stability_fields <- c("mean", "median", "sd", "lower", "upper")
  stability_difference <- max(abs(
    as.matrix(result$summary[, stability_fields, drop = FALSE]) -
      as.matrix(nested$summary[, stability_fields, drop = FALSE])
  ))
  stability <- list(
    maximum_summary_difference = stability_difference,
    tolerance = draw_stability_tolerance,
    full_draws = nrow(model$draws),
    nested_draws = length(nested_indices),
    within_tolerance = stability_difference <= draw_stability_tolerance
  )

  result <- .add_inverse_context(
    result, d2h_wax, d2h_wax_err, longitude, latitude, elevation,
    model, record_id, stability, return_full
  )
  if (verbose) {
    message(
      "Bayesian inversion status: ", result$status,
      "; calibration-weight ESS = ",
      signif(result$diagnostics$mixture_weight_ess, 4)
    )
  }
  result
}

#' @export
print.leafwax_inverse <- function(x, ...) {
  cat("Leaf-wax Bayesian inversion (", x$status, ")\n", sep = "")
  print(x$summary, row.names = FALSE)
  invisible(x)
}
