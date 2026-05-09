# R/assess_claim.R - Level 1-4 claim taxonomy from manuscript Section 4.5.6.
#
# Phase D of the v0.2.0 paleo-record workflow. Walks the four-level
# claim taxonomy defined in the manuscript and reports the highest
# level the claim survives at, with itemized pass/fail reasons.

#' Assess a paleoclimate claim against the leaf-wax taxonomy
#'
#' Walks the four-level taxonomy from manuscript Section 4.5.6 and
#' reports the highest level a claim survives at. The taxonomy is:
#' \itemize{
#'   \item Level 1: a leaf-wax delta-2-H change occurred between two
#'     intervals. Defensible when the change exceeds analytical
#'     uncertainty and the within-record residual SD `sigma_within`.
#'   \item Level 2: the wax change is consistent with a directional
#'     hydroclimate change. Requires corroborating evidence (multi-
#'     proxy concordance, sedimentological context, or biomarker
#'     evidence for vegetation stability) supplied via
#'     `corroborating_proxies`.
#'   \item Level 3: the wax change implies a quantitative
#'     delta-2-H_precip magnitude. Requires a defended local effective
#'     slope, a defended `sigma_within`, and explicit uncertainty
#'     propagation through the inversion. When `reconstruction` is
#'     NULL the function calls `invert_d2H()` itself.
#'   \item Level 4: the magnitude is uniquely attributable to
#'     precipitation isotope change rather than to vegetation,
#'     source-water seasonality, or evapotranspirative enrichment.
#'     Requires independent stationarity evidence for each non-
#'     precipitation control over the interval.
#' }
#'
#' Use this when a colleague claims that a downcore record shows a
#' specific d2H_precip shift and you want a structured check of which
#' levels of the taxonomy that claim actually clears.
#'
#' @param record Data frame (or list) with at least `d2h_wax` and `age`
#'   columns of equal length. `d2h_wax_err` is optional; defaults to
#'   `claim$sigma_analytical` per row.
#' @param claim Named list specifying the claim. Required fields:
#'   `level` (integer 1-4, the level the user is asserting),
#'   `interval_baseline` (length-2 numeric c(min, max) age window),
#'   `interval_test` (length-2 numeric age window),
#'   `sigma_within` (per mil; from `estimate_sigma_within()`).
#'   Optional fields, used by higher levels:
#'   `sigma_analytical` (default 3),
#'   `rho_t` (default 0; from `estimate_temporal_autocorrelation()`),
#'   `beta_eff` (numeric scalar; required at Level 3+),
#'   `confidence` (default 0.95),
#'   `magnitude_precip` (numeric, the precip-space magnitude the user
#'     asserts; required at Level 3+),
#'   `corroborating_proxies` (list, used at Level 2; the test is
#'     non-empty + named),
#'   `vegetation_stationary`, `seasonal_source_stationary`,
#'   `evapotranspirative_stationary` (each a list with `value` (TRUE)
#'     and a non-empty `evidence` string; required at Level 4).
#' @param reconstruction Optional output of `invert_d2H(..., return_full
#'   = TRUE, interval_type = "fitted")` on the record. When NULL and
#'   the claim's level is 3 or 4, the function runs the inversion
#'   itself with the correct `interval_type`. When supplied directly,
#'   it must be built with `interval_type = "fitted"`: the L3+ contrast
#'   is derived under the assumption that the global residual SD is
#'   not in the posterior (manuscript Section 4.5.3). Passing a
#'   `"predictive"` reconstruction raises an error.
#' @param longitude,latitude Site coordinates, used only when
#'   `reconstruction` is NULL.
#' @param model_name Model to use when running the inversion (default
#'   "baseline_sp").
#' @param ... Additional args forwarded to `invert_d2H()` (e.g.,
#'   elevation, c4_fraction, pft_*, n_posterior_draws).
#'
#' @return A list with elements:
#'   \itemize{
#'     \item `highest_level` - integer in 0:4. 0 means even Level 1
#'       did not clear.
#'     \item `levels` - data frame, one row per level, with columns
#'       `level`, `passed` (logical), `summary` (one-line reason).
#'     \item `details` - per-level lists of computed quantities
#'       (e.g., delta_wax, threshold, p_exceed, missing fields).
#'     \item `claim` - the (validated) claim object.
#'   }
#' @export
assess_claim <- function(record,
                         claim,
                         reconstruction = NULL,
                         longitude = NULL,
                         latitude = NULL,
                         model_name = "baseline_sp",
                         ...) {

  # --- record validation ---------------------------------------------
  if (!is.list(record)) stop("record must be a data.frame or list")
  d2h_wax <- record$d2h_wax %||% record$d2H_wax
  age     <- record$age
  if (is.null(d2h_wax) || is.null(age)) {
    stop("record must contain 'd2h_wax' and 'age' columns")
  }
  if (length(d2h_wax) != length(age)) {
    stop("record$d2h_wax and record$age must have the same length")
  }
  if (any(!is.finite(d2h_wax)) || any(!is.finite(age))) {
    stop("record contains non-finite d2h_wax or age values; remove or ",
         "repair them before calling assess_claim()")
  }
  d2h_wax_err <- record$d2h_wax_err

  # --- claim validation ----------------------------------------------
  # Validate `level` first so users asserting a nonsensical level get
  # the most specific error before the missing-field check fires.
  if (!is.numeric(claim$level %||% NA_real_) ||
      length(claim$level %||% NA_real_) != 1L ||
      !isTRUE(claim$level %in% 1:4)) {
    stop("claim$level must be one of 1, 2, 3, 4")
  }
  required <- c("level", "interval_baseline", "interval_test",
                "sigma_within")
  missing_req <- setdiff(required, names(claim))
  if (length(missing_req) > 0L) {
    stop("claim is missing required fields: ",
         paste(missing_req, collapse = ", "))
  }
  if (!is.numeric(claim$interval_baseline) ||
      length(claim$interval_baseline) != 2L ||
      !is.numeric(claim$interval_test) ||
      length(claim$interval_test) != 2L) {
    stop("claim$interval_baseline and claim$interval_test must each ",
         "be length-2 numeric vectors c(min, max)")
  }
  if (!is.numeric(claim$sigma_within) ||
      length(claim$sigma_within) != 1L ||
      !is.finite(claim$sigma_within) || claim$sigma_within < 0) {
    stop("claim$sigma_within must be a single non-negative numeric value")
  }

  # Defaults for optional fields, with finite-scalar validation. Each
  # of these directly drives the Level 1 threshold; bad inputs upstream
  # (NA, length > 1, non-numeric) need a controlled error here rather
  # than a downstream "condition has length > 1".
  .scalar <- function(x, name, allow_neg = FALSE) {
    if (!is.numeric(x) || length(x) != 1L || !is.finite(x)) {
      stop(sprintf(
        "claim$%s must be a single finite numeric value", name
      ))
    }
    if (!allow_neg && x < 0) {
      stop(sprintf("claim$%s must be non-negative", name))
    }
    x
  }
  sigma_a <- .scalar(claim$sigma_analytical %||% 3, "sigma_analytical")
  rho_t   <- .scalar(claim$rho_t            %||% 0, "rho_t",
                     allow_neg = TRUE)
  conf    <- .scalar(claim$confidence       %||% 0.95, "confidence")
  if (rho_t <= -1 || rho_t >= 1) {
    stop("claim$rho_t must be in (-1, 1)")
  }
  if (conf <= 0 || conf >= 1) {
    stop("claim$confidence must be in (0, 1)")
  }

  # --- subset the record to the two intervals -------------------------
  base_idx <- which(age >= min(claim$interval_baseline) &
                    age <= max(claim$interval_baseline))
  test_idx <- which(age >= min(claim$interval_test) &
                    age <= max(claim$interval_test))
  if (length(base_idx) < 1L) {
    stop("interval_baseline contains no samples")
  }
  if (length(test_idx) < 1L) {
    stop("interval_test contains no samples")
  }

  delta_wax <- mean(d2h_wax[test_idx]) - mean(d2h_wax[base_idx])

  # --- Level 1: wax change exceeds noise -----------------------------
  z <- stats::qnorm(1 - (1 - conf) / 2)
  threshold_wax <- z * sqrt(2 * (1 - rho_t)) *
                   sqrt(claim$sigma_within^2 + sigma_a^2)
  l1_passed  <- abs(delta_wax) > threshold_wax
  l1_summary <- sprintf(
    "delta_wax = %.2f permil; %d%% threshold = %.2f permil (%s)",
    delta_wax, round(100 * conf), threshold_wax,
    if (l1_passed) "PASS" else "FAIL"
  )
  l1_details <- list(
    delta_wax            = delta_wax,
    threshold_wax        = threshold_wax,
    sigma_within         = claim$sigma_within,
    sigma_analytical     = sigma_a,
    rho_t                = rho_t,
    n_baseline           = length(base_idx),
    n_test               = length(test_idx)
  )

  # --- Level 2: corroborating evidence supplied -----------------------
  # Require each entry to be named AND to carry non-empty, non-NA
  # evidence content. Strings must be non-empty after whitespace strip;
  # any other object type passes the structural check (we accept
  # arbitrary evidence objects, e.g., a tibble of proxy data, as long
  # as they are not NA and have positive length).
  cor_p <- claim$corroborating_proxies
  has_cor <- FALSE
  bad_cor <- character(0)
  if (is.list(cor_p) && length(cor_p) > 0L &&
      !is.null(names(cor_p)) && all(nzchar(names(cor_p)))) {
    cor_ok <- vapply(cor_p, function(v) {
      if (is.null(v) || (length(v) == 1L && is.na(v))) return(FALSE)
      if (is.character(v)) {
        return(any(nzchar(trimws(v)), na.rm = TRUE))
      }
      length(v) > 0L
    }, logical(1L))
    has_cor <- all(cor_ok)
    if (!has_cor) bad_cor <- names(cor_p)[!cor_ok]
  }
  l2_passed <- l1_passed && has_cor
  if (!l1_passed) {
    l2_summary <- "blocked by Level 1 failure"
  } else if (!is.list(cor_p) || length(cor_p) == 0L ||
             is.null(names(cor_p)) || !all(nzchar(names(cor_p)))) {
    l2_summary <- "no named corroborating_proxies supplied"
  } else if (!has_cor) {
    l2_summary <- sprintf(
      "corroborating_proxies present but empty/NA for: %s",
      paste(bad_cor, collapse = ", "))
  } else {
    l2_summary <- sprintf("corroborating_proxies supplied: %s",
                          paste(names(cor_p), collapse = ", "))
  }
  l2_details <- list(
    corroborating_proxies = cor_p
  )

  # --- Level 3: defended slope + sigma_within + propagated inversion --
  l3_missing <- character(0)
  beta_eff <- claim$beta_eff
  if (is.null(beta_eff) || !is.numeric(beta_eff) ||
      length(beta_eff) != 1L || !is.finite(beta_eff) ||
      abs(beta_eff) < .Machine$double.eps^0.5) {
    l3_missing <- c(l3_missing, "beta_eff (defended local effective slope)")
  }
  mag_precip <- claim$magnitude_precip
  if (is.null(mag_precip) || !is.numeric(mag_precip) ||
      length(mag_precip) != 1L || !is.finite(mag_precip)) {
    l3_missing <- c(l3_missing, "magnitude_precip (asserted precip-space magnitude)")
  }

  l3_details <- list(missing = l3_missing)

  if (l2_passed && length(l3_missing) == 0L) {
    # Build / re-use the reconstruction. When we build it ourselves,
    # the inner invert_d2H() already emits the preview-tier warning,
    # so silence it there and re-emit at this layer with the L3+
    # context. When the user supplies the reconstruction directly,
    # there was no inner warning, and we need to emit the first one.
    built_internally <- is.null(reconstruction)
    if (built_internally) {
      if (is.null(longitude) || is.null(latitude)) {
        stop("Level 3+ assessment without an explicit reconstruction ",
             "requires longitude and latitude to run invert_d2H().")
      }
      n_obs <- length(d2h_wax)
      reconstruction <- withCallingHandlers(
        invert_d2H(
          d2H_wax    = d2h_wax,
          d2H_wax_sd = if (!is.null(d2h_wax_err)) d2h_wax_err else rep(sigma_a, n_obs),
          longitude  = rep(longitude, n_obs),
          latitude   = rep(latitude,  n_obs),
          model_name = model_name,
          sigma_within = claim$sigma_within,
          slope        = beta_eff,
          return_full  = TRUE,
          verbose      = FALSE,
          interval_type = "fitted",
          ...
        ),
        warning = function(w) {
          if (grepl("^leafwax preview posteriors in use",
                    conditionMessage(w))) {
            invokeRestart("muffleWarning")
          }
        }
      )
    }
    if (is.null(reconstruction$posterior_draws)) {
      stop("reconstruction must be invert_d2H(..., return_full = TRUE) ",
           "and contain $posterior_draws")
    }
    rec_interval <- attr(reconstruction, "leafwax_interval_type") %||%
                    reconstruction$model_info$interval_type %||%
                    NA_character_
    if (!is.na(rec_interval) && identical(rec_interval, "predictive")) {
      stop("assess_claim L3+ requires invert_d2H(..., interval_type = ",
           "\"fitted\"); the predictive interval includes the global ",
           "residual sigma, which inflates within-record p_exceed ",
           "(manuscript Section 4.5.3). Rebuild the reconstruction with ",
           "interval_type = \"fitted\" or omit it and let assess_claim ",
           "build it internally.")
    }
    # Re-emit the preview-tier warning at the inferential layer using
    # the *reconstruction's* own model name — the user-supplied
    # reconstruction may have been built from a different model than
    # `model_name`, and pointing them at the wrong download URL is a
    # silent footgun.
    rec_tier <- attr(reconstruction, "leafwax_tier") %||%
                reconstruction$model_info$tier %||% "unknown"
    rec_model <- reconstruction$model_info$model_name %||% model_name
    if (identical(rec_tier, "light")) {
      warn_preview_tier(rec_model,
                        nrow(reconstruction$posterior_draws),
                        "assess_claim L3+")
    }
    draws <- as.matrix(reconstruction$posterior_draws)
    if (ncol(draws) != length(d2h_wax)) {
      stop(sprintf(
        "reconstruction has %d sample columns but record has %d rows",
        ncol(draws), length(d2h_wax)
      ))
    }
    mu_b <- if (length(base_idx) == 1L) draws[, base_idx]
            else rowMeans(draws[, base_idx, drop = FALSE])
    mu_t <- if (length(test_idx) == 1L) draws[, test_idx]
            else rowMeans(draws[, test_idx, drop = FALSE])
    delta_post <- mu_t - mu_b
    p_exceed   <- mean(abs(delta_post) >= abs(mag_precip))

    l3_details$delta_post_median <- stats::median(delta_post)
    l3_details$delta_post_lower  <- stats::quantile(delta_post,
                                                    (1 - conf) / 2,
                                                    names = FALSE)
    l3_details$delta_post_upper  <- stats::quantile(delta_post,
                                                    1 - (1 - conf) / 2,
                                                    names = FALSE)
    l3_details$asserted_magnitude_precip <- mag_precip
    l3_details$posterior_p_exceed <- p_exceed

    l3_passed <- p_exceed >= conf
    l3_summary <- sprintf(
      "P(|delta_precip| >= %.2f permil) = %.3f vs threshold %.2f (%s)",
      mag_precip, p_exceed, conf,
      if (l3_passed) "PASS" else "FAIL"
    )
  } else {
    l3_passed <- FALSE
    if (!l2_passed) {
      l3_summary <- "blocked by Level 2 failure"
    } else {
      l3_summary <- sprintf("missing required fields: %s",
                            paste(l3_missing, collapse = "; "))
    }
  }

  # --- Level 4: independent stationarity evidence --------------------
  l4_required <- c("vegetation_stationary",
                   "seasonal_source_stationary",
                   "evapotranspirative_stationary")
  l4_missing  <- character(0)
  for (k in l4_required) {
    s <- claim[[k]]
    # Reject NA / non-character evidence explicitly. nzchar(NA) returns
    # TRUE by default, so the older check let stationarity_evidence =
    # NA_character_ pass; that promotes a Level 3 claim to Level 4 with
    # missing evidence. Require a non-empty character scalar after
    # whitespace stripping.
    ok <- is.list(s) && isTRUE(s$value)
    if (ok) {
      e <- s$evidence
      ok <- is.character(e) && length(e) == 1L &&
            !is.na(e) && nzchar(trimws(e))
    }
    if (!ok) {
      l4_missing <- c(l4_missing,
        sprintf("%s (need list(value = TRUE, evidence = <non-empty character>))",
                k))
    }
  }
  if (l3_passed && length(l4_missing) == 0L) {
    l4_passed  <- TRUE
    l4_summary <- "all stationarity controls supplied with evidence"
  } else if (!l3_passed) {
    l4_passed  <- FALSE
    l4_summary <- "blocked by Level 3 failure"
  } else {
    l4_passed  <- FALSE
    l4_summary <- sprintf("missing/incomplete: %s",
                          paste(l4_missing, collapse = "; "))
  }
  l4_details <- list(missing = l4_missing)

  passed_vec <- c(L1 = l1_passed, L2 = l2_passed,
                  L3 = l3_passed, L4 = l4_passed)
  highest_level <- if (any(passed_vec)) max(which(passed_vec)) else 0L

  levels_df <- data.frame(
    level   = 1:4,
    passed  = unname(passed_vec),
    summary = c(l1_summary, l2_summary, l3_summary, l4_summary),
    stringsAsFactors = FALSE
  )

  asserted <- claim$level
  asserted_supported <- asserted <= highest_level

  list(
    highest_level         = highest_level,
    asserted_level        = asserted,
    asserted_supported    = asserted_supported,
    levels                = levels_df,
    details = list(
      L1 = l1_details,
      L2 = l2_details,
      L3 = l3_details,
      L4 = l4_details
    ),
    claim = claim
  )
}
