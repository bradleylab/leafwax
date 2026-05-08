# Estimate within-record residual SD from a stationary baseline
# interval of a sedimentary leaf-wax record. Implements the
# sigma_within obligation from manuscript Section 4.5.3: a defensible
# within-record residual standard deviation must come from the record
# itself, not from the global posterior sigma.

#' Estimate the within-record residual SD of a leaf-wax record
#'
#' Estimate a within-record residual standard deviation `sigma_within`
#' from a stratigraphic baseline interval of a downcore leaf-wax
#' delta-2-H record. Within-record residual variance is generally smaller
#' than the global posterior sigma, because spatial structure cancels and
#' between-site sources of variance (laboratory, vegetation background,
#' basin size, integration timescale) do not vary inside a single record.
#' Manuscript Section 4.5.3 explains why and frames the obligations on
#' the user.
#'
#' The function operates on the baseline interval only. With
#' `baseline_interval = NULL`, the entire record is treated as the
#' baseline and a warning is emitted: this conflates real climate
#' variability with measurement and process noise, so the returned
#' `sigma_within` is an upper bound rather than a defended estimate.
#' Real use should specify a stratigraphic interval over which
#' stationarity of vegetation, hydrology, and source-water seasonality
#' can be defended on independent grounds.
#'
#' Within the baseline window, the function:
#' \enumerate{
#'   \item subsets the record to the baseline,
#'   \item optionally detrends (`"linear"` or `"loess"`) to remove
#'     long-wavelength trends that the user does not want absorbed
#'     into the residual SD,
#'   \item computes the lag-1 temporal autocorrelation (`rho_t`)
#'     of the residuals,
#'   \item returns the naive standard deviation of the residuals
#'     (`sd(residuals)`) and an AR(1)-corrected effective SD when
#'     `ar1_correction = TRUE`. The correction is
#'     `sigma_eff = sigma_naive * sqrt(1 - rho_t^2)` for `|rho_t| < 1`,
#'     a conservative reduction that accounts for the variance
#'     sequential samples share.
#' }
#'
#' The standard error of `sigma_within` is approximated by
#' `sigma_within / sqrt(2 * (n_baseline - 1))`, the asymptotic SE of
#' a normal-distribution sample SD.
#'
#' @param d2h_wax Numeric vector of leaf-wax delta-2-H measurements
#'   (per mil).
#' @param age Numeric vector of sample ages (any monotone time-like
#'   variable; same length as `d2h_wax`).
#' @param baseline_interval Length-2 numeric `c(min, max)` defining the
#'   baseline window in `age` units. `NULL` means use the full record
#'   (warning emitted).
#' @param detrend One of `"none"` (default), `"linear"`, or `"loess"`,
#'   describing how to remove trends within the baseline before
#'   computing residuals. `"linear"` fits `lm(d2h_wax ~ age)`.
#'   `"loess"` fits `loess(d2h_wax ~ age, span = 0.75)`.
#' @param ar1_correction Logical (default `TRUE`); if `TRUE`, applies
#'   the AR(1) variance reduction described above.
#' @return A list with elements:
#'   \itemize{
#'     \item `sigma_within` - point estimate (per mil), AR(1)-corrected
#'       if requested.
#'     \item `sigma_within_se` - asymptotic standard error of the
#'       returned `sigma_within`.
#'     \item `sigma_naive` - sample SD of residuals before AR(1)
#'       correction.
#'     \item `n_baseline` - number of samples used.
#'     \item `rho_t_baseline` - lag-1 temporal autocorrelation of
#'       residuals in the baseline.
#'     \item `method` - one-line description of the choices made.
#'   }
#' @export
#' @examples
#' \donttest{
#' # Synthetic stationary baseline: noise around a flat mean
#' set.seed(1)
#' n  <- 80
#' ag <- seq(0, 8000, length.out = n)
#' d  <- -160 + rnorm(n, 0, 5)
#' est <- estimate_sigma_within(d, ag,
#'                              baseline_interval = c(0, 4000),
#'                              detrend = "none",
#'                              ar1_correction = TRUE)
#' est$sigma_within
#' }
estimate_sigma_within <- function(d2h_wax,
                                  age,
                                  baseline_interval = NULL,
                                  detrend = c("none", "linear", "loess"),
                                  ar1_correction = TRUE) {

  detrend <- match.arg(detrend)

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
    warning(
      sprintf(
        paste("estimate_sigma_within() dropped %d row(s) with non-finite",
              "d2h_wax or age (indices: %s). Baseline n and the returned",
              "SD reflect the kept rows only."),
        n_dropped,
        paste(utils::head(dropped_idx, 10),
              if (length(dropped_idx) > 10) "..." else "",
              collapse = ", ")
      ),
      call. = FALSE
    )
  }
  d2h_wax <- d2h_wax[ok]
  age     <- age[ok]
  if (length(d2h_wax) < 4L) {
    stop("estimate_sigma_within() needs at least 4 finite (d2h_wax, age) pairs")
  }

  # Subset to the baseline window.
  if (is.null(baseline_interval)) {
    warning(
      "baseline_interval is NULL; treating the full record as the baseline. ",
      "This conflates real climate variability with measurement/process ",
      "noise, so the returned sigma_within is an upper bound rather than ",
      "a defended estimate. See manuscript Section 4.5.3."
    )
    in_window <- rep(TRUE, length(d2h_wax))
  } else {
    if (!is.numeric(baseline_interval) || length(baseline_interval) != 2L) {
      stop("baseline_interval must be a numeric vector of length 2: c(min, max)")
    }
    lo <- min(baseline_interval); hi <- max(baseline_interval)
    in_window <- age >= lo & age <= hi
  }

  d_b <- d2h_wax[in_window]
  a_b <- age[in_window]
  n_b <- length(d_b)
  if (n_b < 4L) {
    stop("baseline_interval contains fewer than 4 samples; cannot estimate ",
         "sigma_within")
  }

  # Detrend within the baseline.
  resid <- switch(
    detrend,
    "none"   = d_b - mean(d_b),
    "linear" = stats::residuals(stats::lm(d_b ~ a_b)),
    "loess"  = {
      ord <- order(a_b)
      lo_fit <- stats::loess(d_b[ord] ~ a_b[ord], span = 0.75,
                             control = stats::loess.control(surface = "direct"))
      r <- stats::residuals(lo_fit)
      r[order(ord)]
    }
  )

  sigma_naive <- stats::sd(resid)

  # Lag-1 temporal autocorrelation of residuals. Order the residuals by
  # age first; on irregular sampling this is an approximation, but it
  # matches the AR(1)-correction users expect for downcore series.
  ord     <- order(a_b)
  resid_o <- resid[ord]
  if (n_b >= 3L) {
    rho_t <- stats::cor(resid_o[-n_b], resid_o[-1], use = "pairwise.complete.obs")
  } else {
    rho_t <- NA_real_
  }

  # AR(1) correction.
  if (isTRUE(ar1_correction) && is.finite(rho_t) && abs(rho_t) < 1) {
    sigma_within <- sigma_naive * sqrt(1 - rho_t^2)
  } else {
    sigma_within <- sigma_naive
  }

  # Asymptotic SE on the SD of a normal sample.
  sigma_within_se <- sigma_within / sqrt(2 * max(n_b - 1L, 1L))

  method <- paste0(
    "baseline_interval=",
    if (is.null(baseline_interval)) "full record (WARNING)" else
      sprintf("[%.4g, %.4g]",
              min(baseline_interval), max(baseline_interval)),
    "; detrend=", detrend,
    "; ar1_correction=", isTRUE(ar1_correction)
  )

  list(
    sigma_within     = sigma_within,
    sigma_within_se  = sigma_within_se,
    sigma_naive      = sigma_naive,
    n_baseline       = n_b,
    rho_t_baseline   = rho_t,
    method           = method
  )
}
