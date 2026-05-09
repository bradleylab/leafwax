# R/detect_change.R - Within-record change detection for downcore
# d2H_precip reconstructions.
#
# Phase C of the v0.2.0 paleo-record workflow. Implements the within-
# record change-detection threshold from manuscript Section 4.5.3 and
# computes the posterior probability that ΔδD_precip between two
# stratigraphic intervals exceeds a user-supplied magnitude.

#' Estimate lag-1 temporal autocorrelation
#'
#' Estimate the lag-1 autocorrelation `rho_t` of a leaf-wax record's
#' residuals after a flat-mean detrend, ordering by age. This is the
#' quantity that enters the within-record detection threshold from
#' manuscript Section 4.5.3 (`Var(X1 - X2) = 2 sigma^2 (1 - rho_t)`).
#'
#' Two methods are supported:
#' \itemize{
#'   \item `"ar1"` (default): Pearson correlation of `resid[-n]` with
#'     `resid[-1]` after age-ordering. For irregularly sampled series
#'     this is an approximation; see `"lomb_scargle"` for an
#'     alternative.
#'   \item `"lomb_scargle"`: not yet implemented. Returns an error
#'     pointing the user at `"ar1"` until the spectral implementation
#'     lands. The plan is to estimate `rho_t` from the dominant
#'     timescale of a Lomb-Scargle periodogram on the irregularly
#'     sampled series.
#' }
#'
#' @param d2h_wax Numeric vector of leaf-wax delta-2-H measurements
#'   (per mil).
#' @param age Numeric vector of sample ages, same length as `d2h_wax`.
#' @param method One of `"ar1"` or `"lomb_scargle"`.
#' @return Numeric scalar in `[-1, 1]`, or `NA_real_` when the residuals
#'   are constant (e.g., n < 3 finite samples).
#' @export
#' @examples
#' \donttest{
#' set.seed(1)
#' n <- 200
#' rho <- 0.7
#' e  <- numeric(n); e[1] <- rnorm(1, 0, 5)
#' for (k in 2:n) e[k] <- rho * e[k-1] + rnorm(1, 0, 5 * sqrt(1 - rho^2))
#' ag <- seq(0, 10000, length.out = n)
#' estimate_temporal_autocorrelation(-150 + e, ag)
#' }
estimate_temporal_autocorrelation <- function(d2h_wax, age,
                                              method = c("ar1", "lomb_scargle")) {
  method <- match.arg(method)
  if (!is.numeric(d2h_wax) || !is.numeric(age)) {
    stop("d2h_wax and age must be numeric vectors")
  }
  if (length(d2h_wax) != length(age)) {
    stop("d2h_wax and age must have the same length")
  }

  ok <- is.finite(d2h_wax) & is.finite(age)
  n_dropped <- sum(!ok)
  if (n_dropped > 0L) {
    dropped_idx <- which(!ok)
    warning(sprintf(
      paste("estimate_temporal_autocorrelation() dropped %d row(s) with",
            "non-finite d2h_wax or age (indices: %s). With irregular",
            "missingness, lag-1 correlation can mistake non-adjacent",
            "samples for neighbors; review the dropped rows."),
      n_dropped,
      paste(utils::head(dropped_idx, 10),
            if (length(dropped_idx) > 10) "..." else "",
            collapse = ", ")
    ), call. = FALSE)
  }
  if (sum(ok) < 3L) {
    return(NA_real_)
  }
  d <- d2h_wax[ok]
  a <- age[ok]
  ord <- order(a)
  d_o <- d[ord]
  resid <- d_o - mean(d_o)
  n <- length(resid)

  if (method == "lomb_scargle") {
    stop("estimate_temporal_autocorrelation(method = 'lomb_scargle') is not ",
         "yet implemented; use method = 'ar1' for now. The Lomb-Scargle ",
         "spectral estimator is planned for v0.3.")
  }

  rho <- stats::cor(resid[-n], resid[-1], use = "pairwise.complete.obs")
  if (!is.finite(rho)) NA_real_ else rho
}


#' Within-record d2H_precip change detection
#'
#' Given a downcore `invert_d2H()` reconstruction posterior with full
#' draws (`return_full = TRUE`), report (a) the posterior probability
#' that the difference in mean `d2H_precip` between two stratigraphic
#' intervals exceeds user-supplied magnitudes, and (b) the within-
#' record 95\% (or other) detection threshold from manuscript Section
#' 4.5.3:
#'
#' \deqn{\mathrm{threshold}_{precip} =
#'       \frac{z_{\alpha/2}\, \sqrt{2(1 - \rho_t)}\,
#'             \sqrt{\sigma_{within}^2 + \sigma_{analytical}^2}}
#'            {\beta_{\mathrm{eff}}}}
#'
#' The threshold is the smallest difference in `d2H_precip` between two
#' independent samples that can be distinguished from within-record
#' noise at the chosen confidence level.
#'
#' @param reconstruction Output of `invert_d2H(..., return_full = TRUE,
#'   uncertainty_mode = "within_record", sigma_within = ...)` on a
#'   downcore series. Must contain a `posterior_draws` matrix of shape
#'   `n_iter x n_samples`. The reconstruction must be built in
#'   within-record mode with a positive `sigma_within`: the
#'   change-detection threshold formula and `p_exceed` are derived
#'   under the within-record substitution where `sigma_within`
#'   replaces the global residual SD (manuscript Section 4.5.3).
#'   Passing an absolute-mode reconstruction, or one without a
#'   recorded `sigma_within`, raises an error.
#' @param age Numeric vector, length `n_samples`, of sample ages
#'   matching the reconstruction columns.
#' @param baseline_interval Length-2 numeric `c(min, max)` defining the
#'   baseline window in `age` units.
#' @param test_intervals Either a length-2 numeric vector for a single
#'   test window, or a named list of length-2 numerics for multiple
#'   windows. NULL skips the per-interval probability table and returns
#'   only the threshold.
#' @param sigma_within Numeric, required, the within-record residual SD
#'   in leaf-wax per mil (typically from `estimate_sigma_within()`).
#' @param sigma_analytical Numeric, the analytical uncertainty on
#'   `d2H_wax` measurements in per mil (default 3).
#' @param rho_t Numeric, lag-1 temporal autocorrelation. Use
#'   `estimate_temporal_autocorrelation()` to compute. Defaults to 0
#'   (independent samples) with a message.
#' @param beta_eff Numeric, the local effective slope. Use
#'   `local_effective_slope()` for a point estimate (e.g., its median).
#' @param confidence Numeric in (0, 1), the confidence level for the
#'   detection threshold. Default 0.95.
#' @param magnitudes Optional numeric vector of magnitudes (per mil) to
#'   evaluate posterior `Pr(|delta| > magnitude)` against.
#'
#' @return A list with elements:
#'   \itemize{
#'     \item `threshold` - the detection threshold on `d2H_precip` at
#'       the requested confidence level.
#'     \item `formula` - the components used: `z`, `rho_t`,
#'       `sigma_within`, `sigma_analytical`, `beta_eff`.
#'     \item `intervals` - a data frame with one row per test interval
#'       reporting the posterior median and CI of `delta` and (if
#'       `magnitudes` supplied) the posterior probability of exceeding
#'       each magnitude.
#'   }
#' @export
detect_change <- function(reconstruction,
                          age,
                          baseline_interval,
                          test_intervals = NULL,
                          sigma_within,
                          sigma_analytical = 3,
                          rho_t = NULL,
                          beta_eff,
                          confidence = 0.95,
                          magnitudes = NULL) {

  # --- input validation -----------------------------------------------
  if (!is.list(reconstruction) || is.null(reconstruction$posterior_draws)) {
    stop("reconstruction must be the list returned by ",
         "invert_d2H(..., return_full = TRUE) and contain ",
         "$posterior_draws")
  }
  rec_mode <- attr(reconstruction, "leafwax_uncertainty_mode") %||%
              reconstruction$model_info$uncertainty_mode %||%
              NA_character_
  rec_sigma_w <- attr(reconstruction, "leafwax_sigma_within") %||%
                 reconstruction$model_info$sigma_within %||%
                 NA_real_
  if (is.na(rec_mode) || !identical(rec_mode, "within_record")) {
    stop("detect_change requires invert_d2H(..., ",
         "uncertainty_mode = \"within_record\", sigma_within = ...); ",
         "the absolute mode uses the global residual sigma, which ",
         "miscalibrates the change-detection threshold and the ",
         "posterior p_exceed (manuscript Section 4.5.3). Rebuild the ",
         "reconstruction with uncertainty_mode = \"within_record\" ",
         "and a record-specific sigma_within.")
  }
  if (is.na(rec_sigma_w) || rec_sigma_w <= 0) {
    stop("Reconstruction passed to detect_change has no positive ",
         "sigma_within recorded. Manuscript Section 4.5.3 requires a ",
         "record-specific sigma_within for within-record contrasts. ",
         "Rebuild the reconstruction with a positive sigma_within.")
  }
  # Cross-check the reconstruction's sigma_within against the function
  # arg only when the function arg is itself a valid number; an invalid
  # arg is handled by the dedicated sigma_within validation below and
  # should not also surface as a mismatch warning.
  if (is.numeric(sigma_within) && length(sigma_within) == 1L &&
      is.finite(sigma_within) && sigma_within >= 0 &&
      !isTRUE(all.equal(rec_sigma_w, sigma_within, tolerance = 1e-6))) {
    warning(sprintf(
      "Reconstruction was built with sigma_within = %g but detect_change was called with sigma_within = %g. The threshold formula will use the detect_change value (%g); the reconstruction posterior carries %g. Re-run invert_d2H with the same sigma_within for consistency.",
      rec_sigma_w, sigma_within, sigma_within, rec_sigma_w
    ), call. = FALSE)
  }
  # Re-raise the preview-tier warning at the change-detection layer.
  # Posterior-probability statements (`p_exceed`) are exactly what the
  # 100-draw fixture estimates poorly.
  rec_tier <- attr(reconstruction, "leafwax_tier") %||%
              reconstruction$model_info$tier %||% "unknown"
  rec_model <- reconstruction$model_info$model_name %||% "<unknown>"
  if (identical(rec_tier, "light")) {
    warn_preview_tier(rec_model,
                      nrow(reconstruction$posterior_draws),
                      "detect_change")
  }
  draws <- reconstruction$posterior_draws
  if (!is.matrix(draws)) draws <- as.matrix(draws)
  n_iter <- nrow(draws)
  n_obs  <- ncol(draws)

  if (!is.numeric(age) || length(age) != n_obs) {
    stop(sprintf(
      "age must be numeric with length n_samples (%d); got length %d",
      n_obs, if (is.null(age)) 0L else length(age)
    ))
  }
  if (any(!is.finite(age))) {
    bad_idx <- which(!is.finite(age))
    stop(sprintf(
      paste("age contains %d non-finite value(s) at indices: %s.",
            "Refusing to silently drop samples; remove or repair the",
            "ages and re-run detect_change()."),
      length(bad_idx),
      paste(utils::head(bad_idx, 10),
            if (length(bad_idx) > 10) "..." else "",
            collapse = ", ")
    ))
  }

  if (!is.numeric(baseline_interval) || length(baseline_interval) != 2L) {
    stop("baseline_interval must be a numeric vector of length 2: c(min, max)")
  }
  if (missing(sigma_within) || is.null(sigma_within) ||
      !is.numeric(sigma_within) || length(sigma_within) != 1L ||
      !is.finite(sigma_within) || sigma_within < 0) {
    stop("sigma_within must be a single non-negative numeric value (per mil)")
  }
  if (!is.numeric(sigma_analytical) || length(sigma_analytical) != 1L ||
      !is.finite(sigma_analytical) || sigma_analytical < 0) {
    stop("sigma_analytical must be a single non-negative numeric value (per mil)")
  }
  if (missing(beta_eff) || !is.numeric(beta_eff) || length(beta_eff) != 1L ||
      !is.finite(beta_eff) || abs(beta_eff) < .Machine$double.eps^0.5) {
    stop("beta_eff must be a single non-zero finite numeric value")
  }
  if (!is.numeric(confidence) || length(confidence) != 1L ||
      !is.finite(confidence) || confidence <= 0 || confidence >= 1) {
    stop("confidence must be a single value in (0, 1)")
  }

  if (is.null(rho_t)) {
    message("detect_change(): rho_t not supplied; assuming rho_t = 0 ",
            "(independent samples). Use estimate_temporal_autocorrelation() ",
            "to compute it from the record.")
    rho_t <- 0
  }
  if (!is.numeric(rho_t) || length(rho_t) != 1L ||
      !is.finite(rho_t) || rho_t <= -1 || rho_t >= 1) {
    stop("rho_t must be a single finite value in (-1, 1)")
  }

  # --- detection threshold (manuscript Section 4.5.3) -----------------
  z <- stats::qnorm(1 - (1 - confidence) / 2)
  sigma_combined <- sqrt(sigma_within^2 + sigma_analytical^2)
  threshold_wax    <- z * sqrt(2 * (1 - rho_t)) * sigma_combined
  threshold_precip <- threshold_wax / abs(beta_eff)

  # --- per-interval posterior probabilities --------------------------
  intervals_df <- NULL
  if (!is.null(test_intervals)) {
    # Normalize test_intervals to a named list of length-2 numerics.
    if (is.numeric(test_intervals) && length(test_intervals) == 2L) {
      test_intervals <- list(test = test_intervals)
    }
    if (!is.list(test_intervals)) {
      stop("test_intervals must be a length-2 numeric vector or a named ",
           "list of length-2 numerics")
    }
    if (is.null(names(test_intervals)) ||
        any(!nzchar(names(test_intervals)))) {
      names(test_intervals) <- paste0("interval_", seq_along(test_intervals))
    }

    base_idx <- which(age >= min(baseline_interval) &
                      age <= max(baseline_interval))
    if (length(base_idx) < 1L) {
      stop("baseline_interval contains no samples")
    }

    rows <- vector("list", length(test_intervals))
    for (k in seq_along(test_intervals)) {
      iv <- test_intervals[[k]]
      if (!is.numeric(iv) || length(iv) != 2L) {
        stop(sprintf(
          "test_intervals[[%s]] must be a length-2 numeric c(min, max)",
          names(test_intervals)[k]
        ))
      }
      test_idx <- which(age >= min(iv) & age <= max(iv))
      if (length(test_idx) < 1L) {
        warning(sprintf(
          "test_interval '%s' contains no samples; reporting NA",
          names(test_intervals)[k]
        ))
        rows[[k]] <- data.frame(
          interval     = names(test_intervals)[k],
          n_baseline   = length(base_idx),
          n_test       = 0L,
          delta_mean   = NA_real_,
          delta_median = NA_real_,
          delta_lower  = NA_real_,
          delta_upper  = NA_real_,
          stringsAsFactors = FALSE
        )
        next
      }
      mu_base <- if (length(base_idx) == 1L) draws[, base_idx]
                 else rowMeans(draws[, base_idx, drop = FALSE])
      mu_test <- if (length(test_idx) == 1L) draws[, test_idx]
                 else rowMeans(draws[, test_idx, drop = FALSE])
      delta <- mu_test - mu_base
      ci_lo <- (1 - confidence) / 2
      row_df <- data.frame(
        interval     = names(test_intervals)[k],
        n_baseline   = length(base_idx),
        n_test       = length(test_idx),
        delta_mean   = mean(delta),
        delta_median = stats::median(delta),
        delta_lower  = stats::quantile(delta, probs = ci_lo,    names = FALSE),
        delta_upper  = stats::quantile(delta, probs = 1 - ci_lo, names = FALSE),
        stringsAsFactors = FALSE
      )
      if (!is.null(magnitudes)) {
        if (!is.numeric(magnitudes) || any(!is.finite(magnitudes))) {
          stop("magnitudes must be a finite numeric vector (per mil)")
        }
        for (m in magnitudes) {
          col <- sprintf("p_abs_delta_gt_%g", m)
          row_df[[col]] <- mean(abs(delta) > abs(m))
        }
      }
      rows[[k]] <- row_df
    }
    intervals_df <- do.call(rbind, rows)
    rownames(intervals_df) <- NULL
  }

  list(
    threshold = threshold_precip,
    formula = list(
      z                 = z,
      confidence        = confidence,
      rho_t             = rho_t,
      sigma_within      = sigma_within,
      sigma_analytical  = sigma_analytical,
      sigma_combined    = sigma_combined,
      beta_eff          = beta_eff,
      threshold_wax     = threshold_wax,
      threshold_precip  = threshold_precip
    ),
    intervals = intervals_df
  )
}
