# R/invert_d2h.R

#' @importFrom stats rnorm median sd quantile dist
NULL

#' Invert leaf wax d2H to precipitation d2H
#' 
#' Uses Bayesian posterior draws to invert leaf wax hydrogen isotope values
#' to precipitation isotope values, accounting for all model components including
#' elevation effects and spatial correlations.
#' 
#' @param d2h_wax Numeric vector of leaf wax d2H values (per mil)
#' @param d2h_wax_err Numeric vector of measurement uncertainties (per mil)
#' @param longitude Numeric vector of longitudes (decimal degrees)
#' @param latitude Numeric vector of latitudes (decimal degrees)
#' @param elevation Numeric vector of elevations (meters)
#' @param c4_percent Numeric vector of C4 vegetation percentage (0-100)
#' @param pft_tree Numeric vector of tree PFT fraction (0-1)
#' @param pft_shrub Numeric vector of shrub PFT fraction (0-1)
#' @param pft_grass Numeric vector of grass PFT fraction (0-1)
#' @param model_name Character string specifying which model to use (default: "baseline").
#'   Available models: "baseline", "baseline_sp", "baseline_env", "baseline_env_sp",
#'   "baseline_veg", "baseline_veg_sp", "c4_only_sp", "elevation_only_sp",
#'   "elevation_c4_sp", "elevation_c4_interact_sp", "full", "full_sp",
#'   "full_interact", "full_interact_sp". Use available_models() for full list.
#' @param n_draws Integer number of posterior draws to use (NULL for all)
#' @param return_full Logical whether to return full posterior draws or just summary
#' @param credible_level Numeric credible interval level (default 0.9)
#' @param verbose Logical whether to print progress messages
#' @param record_id Character or numeric, optional record identifier.
#'   When supplied and constant across all input rows, all rows are
#'   treated as belonging to the same downcore series: the spatial
#'   Gaussian process is evaluated once per posterior draw at the
#'   shared site, so spatial draws are reused across the series rather
#'   than redrawn per row. The current implementation already shares
#'   spatial draws between identical (longitude, latitude) pairs; the
#'   `record_id` argument adds explicit validation that the caller
#'   intends within-record inference.
#' @param slope Optional numeric override for the d2H_wax-d2H_precip
#'   slope. NULL (default) uses the model's site-specific slope, i.e.,
#'   `beta_oipc` plus the spatial slope GP perturbation at the site.
#'   A single numeric replaces the slope with a fixed point estimate
#'   (broadcast across all posterior draws). A vector of length
#'   `n_draws` is used per draw. Use `local_effective_slope()` to
#'   build a defensible per-draw override that respects the manuscript's
#'   simple-model ceiling at alpha = 0.88 (Section 4.5.5). When
#'   supplied, the override applies uniformly to every input row.
#'
#' @return If return_full is FALSE, a data frame with columns:
#'   \item{d2h_precip_mean}{Mean predicted precipitation d2H}
#'   \item{d2h_precip_median}{Median predicted precipitation d2H}
#'   \item{d2h_precip_sd}{Standard deviation of the posterior
#'     predictive interval}
#'   \item{d2h_precip_lower}{Lower bound of the credible interval}
#'   \item{d2h_precip_upper}{Upper bound of the credible interval}
#'   \item{prediction_interval_width}{Width of the credible interval
#'     (upper - lower).}
#'
#'   The interval is the posterior predictive specified in manuscript
#'   supplement Section S4.1, Eq. 7: the wax-error draw combines
#'   analytical uncertainty with the model's posterior residual SD
#'   `sigma`. For within-record change detection, the spatial GP
#'   intercept's contribution cancels in any contrast computed from
#'   the returned `posterior_draws` (manuscript Section 4.5.3); the
#'   same `sigma` applies in both regimes.
#'
#'   If return_full is TRUE, a list with:
#'   \item{summary}{The summary data frame described above}
#'   \item{posterior_draws}{Matrix of all posterior draws (n_draws x n_locations)}
#'   \item{model_info}{Information about the model used.}
#'   
#' @export
#' 
#' @examples
#' \dontrun{
#' # Simple inversion with base model
#' results <- invert_d2h(
#'   d2h_wax = c(-150, -140, -130),
#'   d2h_wax_err = c(3, 3, 3),
#'   longitude = c(-120, -110, -100),
#'   latitude = c(40, 35, 30),
#'   elevation = c(1000, 1500, 500),
#'   model = "baseline"
#' )
#'
#' # Inversion with spatial model
#' results <- invert_d2h(
#'   d2h_wax = c(-150, -140, -130),
#'   d2h_wax_err = c(3, 3, 3),
#'   longitude = c(-120, -110, -100),
#'   latitude = c(40, 35, 30),
#'   elevation = c(1000, 1500, 500),
#'   model = "baseline_sp",
#'   return_full = TRUE
#' )
#' }
invert_d2h <- function(d2h_wax, d2h_wax_err = NULL,
                       longitude, latitude, elevation = NULL,
                       c4_percent = NULL,
                       pft_tree = NULL, pft_shrub = NULL, pft_grass = NULL,
                       model_name = "baseline",
                       n_draws = NULL,
                       return_full = FALSE,
                       credible_level = 0.9,
                       verbose = TRUE,
                       record_id = NULL,
                       slope = NULL) {

  # Input validation
  n_obs <- length(d2h_wax)
  if (length(longitude) != n_obs || length(latitude) != n_obs) {
    stop("All input vectors must have the same length")
  }

  # record_id validation: when supplied, all rows must share
  # one identifier. The spatial GP at identical (lon, lat) coordinates
  # is already deterministic given each posterior draw, so a constant
  # record_id triggers a verbose acknowledgement plus a coordinate
  # consistency check rather than a separate code path.
  if (!is.null(record_id)) {
    if (length(record_id) == 1L) {
      record_id_vec <- rep(record_id, n_obs)
    } else if (length(record_id) == n_obs) {
      record_id_vec <- record_id
    } else {
      stop("record_id must be length 1 or length(d2h_wax)")
    }
    if (length(unique(record_id_vec)) != 1L) {
      stop("invert_d2H currently supports a single record per call; ",
           "got ", length(unique(record_id_vec)), " unique record_id values. ",
           "Call invert_d2H once per record.")
    }
    if (length(unique(longitude)) != 1L || length(unique(latitude)) != 1L) {
      stop("record_id is constant but longitude/latitude vary across rows. ",
           "All samples in a single record must share one site.")
    }
    if (verbose) {
      cat("  record_id =", record_id_vec[1],
          ": treating", n_obs, "rows as one downcore series ",
          "(spatial GP shared across draws)\n", sep = "")
    }
  }
  
  # Set default uncertainty if not provided. DEFAULT_WAX_ERR_PERMIL is
  # 3 per mil, the typical GC-IRMS analytical uncertainty for delta-2-H_wax.
  if (is.null(d2h_wax_err)) {
    d2h_wax_err <- rep(DEFAULT_WAX_ERR_PERMIL, n_obs)
    if (verbose) cat("Using default measurement uncertainty of ",
                     DEFAULT_WAX_ERR_PERMIL, " per mil\n", sep = "")
  }
  
  # Load the model. Suppress the inner preview-tier warning here and
  # re-emit it below with the "invert_d2H" context, so the user sees
  # one warning at the inferential layer rather than two.
  if (verbose) cat("Loading model:", model_name, "\n")
  model <- withCallingHandlers(
    load_posteriors(model_name, n_draws = n_draws, verbose = verbose),
    warning = function(w) {
      if (grepl("^leafwax preview posteriors in use", conditionMessage(w))) {
        invokeRestart("muffleWarning")
      }
    }
  )
  
  # Check that requested predictors match the model
  model_meta <- model$metadata
  
  if (!is.null(elevation) && !model_meta$has_elevation) {
    warning("Elevation provided but model ", model_name, " does not include elevation effects")
    elevation <- NULL
  }
  
  if (!is.null(c4_percent) && !model_meta$has_c4) {
    warning("C4 percent provided but model ", model_name, " does not include C4 effects")
    c4_percent <- NULL
  }
  
  if (!is.null(pft_tree) && !model_meta$has_pft) {
    warning("PFT values provided but model ", model_name, " does not include PFT effects")
    pft_tree <- pft_shrub <- pft_grass <- NULL
  }
  
  # Set defaults for missing predictors. Values come from constants.R
  # so the policy lives in one place rather than as a row of magic
  # numbers here.
  if (is.null(elevation)) elevation <- rep(0, n_obs)
  if (is.null(c4_percent)) c4_percent <- rep(DEFAULT_C4_PERCENT, n_obs)
  if (is.null(pft_tree))   pft_tree   <- rep(DEFAULT_PFT_TREE,  n_obs)
  if (is.null(pft_shrub))  pft_shrub  <- rep(DEFAULT_PFT_SHRUB, n_obs)
  if (is.null(pft_grass))  pft_grass  <- rep(DEFAULT_PFT_GRASS, n_obs)
  
  # Normalize PFT if needed
  pft_sum <- pft_tree + pft_shrub + pft_grass
  pft_tree <- pft_tree / pft_sum
  pft_shrub <- pft_shrub / pft_sum
  pft_grass <- pft_grass / pft_sum
  
  if (verbose) cat("Performing inversion for", n_obs, "locations\n")
  
  # Get draws
  draws <- model$draws
  n_iter <- nrow(draws)

  # Initialize posterior prediction matrix
  d2h_precip_post <- matrix(NA, nrow = n_iter, ncol = n_obs)

  # Initialize scaling early so the elevation and spatial blocks below
  # can reference it. PLACEHOLDER_SCALING (constants.R) is used when
  # model$scaling is NULL — these are conservative round numbers, not
  # the v10 fitted scales, intended only to keep the inversion
  # numerically stable while we warn the user.
  if (is.null(model$scaling)) {
    scaling <- PLACEHOLDER_SCALING
    warning("Model lacks scaling_params.rds; using PLACEHOLDER_SCALING. ",
            "Reconstructions will not match the v10 fit. Run ",
            "download_model_data(\"", model_name,
            "\") to fetch the calibrated scales.", call. = FALSE)
  } else {
    scaling <- model$scaling
  }

  # Get base parameters
  base_params <- model$get_base_params()
  beta_0 <- base_params$beta_0
  beta_oipc <- base_params$beta_oipc
  sigma <- base_params$sigma
  
  # Get scale weights using lambda_decay
  lambda_decay <- base_params$lambda_decay
  effective_scale <- base_params$effective_scale_km
  
  # Get vegetation parameters if applicable
  beta_c4 <- rep(0, n_iter)
  beta_tree <- rep(0, n_iter)
  beta_shrub <- rep(0, n_iter)
  beta_grass <- rep(0, n_iter)
  
  if (model_meta$has_c4 || model_meta$has_pft) {
    veg_params <- model$get_vegetation_params()
    if (!is.null(veg_params$beta_c4)) beta_c4 <- veg_params$beta_c4
    if (!is.null(veg_params$beta_tree)) beta_tree <- veg_params$beta_tree
    if (!is.null(veg_params$beta_shrub)) beta_shrub <- veg_params$beta_shrub
    if (!is.null(veg_params$beta_grass)) beta_grass <- veg_params$beta_grass
  }
  
  # Elevation effect placeholder. v10 did not fit any beta_elev
  # coefficients (load_posteriors() sets has_elevation only when those
  # columns exist), so this stays at zero. Kept as an explicit term in
  # the linear predictor below for clarity and to leave a hook for
  # future model variants that do include elevation.
  elev_effect <- matrix(0, nrow = n_iter, ncol = n_obs)
  
  # Get dual-GP spatial effects (intercept and slope) at the prediction
  # site(s). v10 uses a Matern 3/2 kernel in standardized 2D coordinate
  # space, with two independent GPs sharing knot positions and length
  # scale but having distinct sigma and z. predict_spatial_dual_gp
  # returns matrices for both fields; intercept goes into mu, slope
  # multiplies oipc in the inversion (below).
  intercept_effect <- matrix(0, nrow = n_iter, ncol = n_obs)
  slope_effect     <- matrix(0, nrow = n_iter, ncol = n_obs)
  if (model_meta$has_gp) {
    if (is.null(model$spatial$knot_locs)) {
      stop("Spatial model loaded without knot_locs; cannot predict at new sites.")
    }
    if (verbose) cat("  Computing dual-GP spatial effects (Matern 3/2)...\n")
    coords_new <- cbind(longitude, latitude)
    dual <- predict_spatial_dual_gp(coords_new, model$spatial$knot_locs,
                                    draws, scaling)
    intercept_effect <- dual$intercept
    slope_effect     <- dual$slope
  }
  
  # Standardize predictors using available scaling
  d2h_wax_std <- (d2h_wax - scaling$d2H_mean) / scaling$d2H_sd
  d2h_wax_err_std <- d2h_wax_err / scaling$d2H_sd

  c4_std <- (c4_percent - scaling$c4_mean) / scaling$c4_sd

  # Caller-supplied slope override. Length-1 broadcasts to all draws;
  # length-n_iter is used per draw. The override replaces the
  # model's beta_oipc + slope_GP path entirely and applies uniformly to
  # every input row (no per-row spatial perturbation when overriding).
  use_slope_override <- !is.null(slope)
  if (use_slope_override) {
    if (!is.numeric(slope) || any(!is.finite(slope))) {
      stop("slope must be a finite numeric value or vector")
    }
    # Reject zero / near-zero slopes: the inversion divides by the
    # slope, so a zero override produces NaN/Inf reconstructions
    # silently. Force the user to supply a positive slope (the simple
    # two-pool fractionation model is bounded above by ~0.88; values
    # at or below zero have no scientific interpretation in this
    # framework).
    if (any(abs(slope) < .Machine$double.eps^0.5)) {
      stop("slope contains values at or near zero; the inversion divides ",
           "by slope and would produce NaN/Inf. Supply a positive slope.")
    }
    if (any(slope < 0)) {
      stop("slope must be positive; got at least one negative value. ",
           "Negative slopes have no interpretation in the d2H_wax<-d2H_precip ",
           "inversion.")
    }
    if (length(slope) == 1L) {
      slope_override <- rep(slope, n_iter)
    } else if (length(slope) == n_iter) {
      slope_override <- slope
    } else {
      stop(sprintf(
        "slope must be length 1 or length n_draws (%d); got %d. ",
        n_iter, length(slope)
      ),
      "Use local_effective_slope(..., n_draws = n) to build a per-draw vector ",
      "of the right size, or pass a single point estimate.")
    }
    if (verbose) {
      cat(sprintf(
        "  Using slope override (range: %.3f to %.3f) instead of the ",
        min(slope_override), max(slope_override)
      ),
      "model's site-specific slope.\n", sep = "")
    }
  }

  # Compute predictions for each location
  if (verbose) cat("Computing predictions...\n")

  for (iter in 1:n_iter) {
    # Build the non-OIPC part of the linear predictor.
    # The OIPC slope (with its spatially-varying perturbation) is handled
    # separately during inversion below.
    mu_std <- beta_0[iter] +
      elev_effect[iter, ] +
      beta_c4[iter] * c4_std +
      beta_tree[iter] * pft_tree +
      beta_shrub[iter] * pft_shrub +
      beta_grass[iter] * pft_grass +
      intercept_effect[iter, ]

    # Site-specific effective slope: global mean plus the spatially-varying
    # perturbation at this location for this draw. v10 fitted a slope GP
    # (z_slope_spatial[*]) on top of the global beta_oipc. When a slope
    # override is supplied, replace the per-row vector with the
    # caller's per-draw scalar (broadcast to every row).
    if (use_slope_override) {
      beta_oipc_eff <- rep(slope_override[iter], n_obs)
    } else {
      beta_oipc_eff <- beta_oipc[iter] + slope_effect[iter, ]
    }

    # Uncertainty propagation (manuscript supplement Eq. 7): the
    # wax-error draw combines analytical uncertainty with the model's
    # posterior residual SD `sigma`. Parameter and spatial uncertainty
    # enter through the per-iteration posterior draws of beta_0,
    # beta_oipc, GP fields, etc. For within-record contrasts the
    # spatial GP intercept's contribution cancels in any difference
    # between time intervals computed downstream from `posterior_draws`
    # (manuscript Section 4.5.3); the same sigma applies in both
    # regimes.
    for (i in 1:n_obs) {
      var_std <- d2h_wax_err_std[i]^2 + sigma[iter]^2
      wax_sd_std <- sqrt(var_std)
      d2h_wax_with_error <- rnorm(1, d2h_wax_std[i], wax_sd_std)

      # Invert to get precipitation d2H (in standardized space). The
      # /beta_oipc_eff[i] step naturally scales any wax-space noise
      # (measurement + within-record residual) by the local effective
      # slope.
      d2h_precip_std <- (d2h_wax_with_error - mu_std[i]) / beta_oipc_eff[i]

      # Back-transform to original scale
      d2h_precip_post[iter, i] <- d2h_precip_std * scaling$oipc_sd + scaling$oipc_mean
    }
  }
  
  # Compute summaries
  alpha <- 1 - credible_level
  lower_q <- alpha / 2
  upper_q <- 1 - alpha / 2
  
  summary_df <- data.frame(
    longitude = longitude,
    latitude = latitude,
    elevation = elevation,
    d2h_wax = d2h_wax,
    d2h_wax_err = d2h_wax_err,
    d2h_precip_mean = colMeans(d2h_precip_post),
    d2h_precip_median = apply(d2h_precip_post, 2, median),
    d2h_precip_sd = apply(d2h_precip_post, 2, sd),
    d2h_precip_lower = apply(d2h_precip_post, 2, quantile, probs = lower_q),
    d2h_precip_upper = apply(d2h_precip_post, 2, quantile, probs = upper_q)
  )

  summary_df$prediction_interval_width <- summary_df$d2h_precip_upper - summary_df$d2h_precip_lower

  if (verbose) {
    cat("\nInversion complete:\n")
    cat("  Mean prediction range: [",
        round(min(summary_df$d2h_precip_mean), 1), ", ",
        round(max(summary_df$d2h_precip_mean), 1), "] per mil\n", sep = "")
    cat("  Mean uncertainty (SD):", round(mean(summary_df$d2h_precip_sd), 1), "per mil\n")
    cat("  Mean ", round(credible_level * 100), "% width: ",
        round(mean(summary_df$prediction_interval_width), 1), " per mil\n", sep = "")
  }
  
  # Tag the result with the posterior tier so downstream inferential
  # functions (assess_claim, detect_change) can warn if the user is
  # operating on the preview fixture.
  tier <- model_meta$tier %||% "unknown"
  if (identical(tier, "light")) {
    warn_preview_tier(model_name, n_iter, "invert_d2H")
  }

  if (return_full) {
    out <- list(
      summary = summary_df,
      posterior_draws = d2h_precip_post,
      model_info = list(
        model_name = model_name,
        n_draws = n_iter,
        n_locations = n_obs,
        tier = tier,
        components_used = c(
          base = TRUE,
          elevation = model_meta$has_elevation && !is.null(elevation),
          c4 = model_meta$has_c4 && !is.null(c4_percent),
          pft = model_meta$has_pft && !is.null(pft_tree),
          spatial = model_meta$has_gp
        )
      )
    )
    attr(out, "leafwax_tier") <- tier
    return(out)
  } else {
    attr(summary_df, "leafwax_tier") <- tier
    return(summary_df)
  }
}

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
                      slope = NULL) {

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
    slope = slope
  )
}

#' Detect model capabilities from model name
#' 
#' @param model_name Name of the model
#' @return List of capability flags
#' @export
detect_model_capabilities <- function(model_name) {
  list(
    has_gp = grepl("sp", model_name),
    has_elevation = grepl("elev", model_name),
    has_c4 = grepl("c4", model_name),
    has_pft = grepl("pft", model_name)
  )
}