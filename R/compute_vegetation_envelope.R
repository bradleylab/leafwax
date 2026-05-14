# R/compute_vegetation_envelope.R - Vegetation-only envelope for the
# magnitude path of the Level 2 claim taxonomy (manuscript §4.5.3).
#
# Holds d2H_precip constant by construction and predicts the wax shift
# expected under a user-supplied PFT-change scenario, propagating the
# full posterior over the four main-effect and four interaction
# coefficients. Output feeds assess_claim() path (b).

# Friendly user-facing PFT label -> Stan posterior column names. The
# posterior columns use lowercase `c4` while the manuscript and the
# user-facing API use `C4`; the map is the single point that bridges
# the two conventions. [FIX-4]
PFT_COEF_MAP <- list(
  tree  = c(main = "beta_tree",  interaction = "beta_oipc_x_tree"),
  shrub = c(main = "beta_shrub", interaction = "beta_oipc_x_shrub"),
  grass = c(main = "beta_grass", interaction = "beta_oipc_x_grass"),
  C4    = c(main = "beta_c4",    interaction = "beta_oipc_x_c4")
)

# Required PFT labels in the user-facing scenario (exact set, exact
# capitalization).
REQUIRED_PFT_LABELS <- c("tree", "shrub", "grass", "C4")

# Validate one user-facing PFT-fraction vector (`from` or `to`).
# Each must be a named numeric over the four labels, all values finite
# in [0, 1], with tree+shrub+grass <= 1 (C4 is an independent fraction
# of grass cover that is C4 photosynthetic, so it does not constrain
# the woody/herbaceous partition).
.validate_pft_vector <- function(x, name) {
  if (!is.numeric(x) || is.null(names(x))) {
    stop(sprintf(
      "`%s` must be a named numeric vector over {tree, shrub, grass, C4}",
      name
    ), call. = FALSE)
  }
  nm <- names(x)
  if (!setequal(nm, REQUIRED_PFT_LABELS)) {
    extra   <- setdiff(nm, REQUIRED_PFT_LABELS)
    missing <- setdiff(REQUIRED_PFT_LABELS, nm)
    msg <- sprintf("`%s` must have names exactly {tree, shrub, grass, C4}", name)
    if (length(missing)) {
      msg <- paste0(msg, "; missing: ", paste(missing, collapse = ", "))
    }
    if (length(extra)) {
      msg <- paste0(msg, "; unrecognized: ", paste(extra, collapse = ", "),
                    " (note: PFT labels are case-sensitive; `C4` is uppercase)")
    }
    stop(msg, call. = FALSE)
  }
  if (any(!is.finite(x))) {
    stop(sprintf("`%s` contains non-finite values", name), call. = FALSE)
  }
  if (any(x < 0) || any(x > 1)) {
    stop(sprintf("`%s` values must be in [0, 1]", name), call. = FALSE)
  }
  veg_sum <- x[["tree"]] + x[["shrub"]] + x[["grass"]]
  if (veg_sum > 1 + 1e-8) {
    stop(sprintf(
      "`%s` violates the compositional constraint tree + shrub + grass <= 1 (got %.4f); C4 is an independent fraction and not part of this sum",
      name, veg_sum
    ), call. = FALSE)
  }
  invisible(TRUE)
}

#' Vegetation-only envelope for a paleo wax-isotope record
#'
#' Computes the posterior-propagated wax-shift envelope expected under
#' a user-supplied PFT-change scenario, holding `d2H_precip` constant.
#' This is the magnitude path of the Level 2 claim taxonomy described
#' in the accompanying manuscript Section 4.5.3: the calibration's PFT
#' main-effect and PFT-by-OIPC interaction coefficients are combined
#' across all posterior draws to bound how much wax change vegetation
#' reorganization alone can produce at the site, with no contribution
#' from precipitation-isotope change.
#'
#' For each posterior draw the per-draw envelope is
#'   `envelope = sum_k beta_k * delta_pft_k +
#'               sum_k beta_oipc_x_k * oipc_ref * delta_pft_k`
#' where `k` indexes the four PFT classes (`tree`, `shrub`, `grass`,
#' `C4`) and `delta_pft_k = to[k] - from[k]`. The returned
#' `envelope_p975_abs = quantile(abs(envelope_draws), 0.975)` is the
#' absolute upper bound used by [assess_claim()] path (b) to test
#' whether an observed `|delta_wax|` exceeds what the supplied PFT
#' scenario alone can produce.
#'
#' Passing path (b) rejects the vegetation-only null for the supplied
#' scenario at the site. It does not identify the hydroclimate
#' mechanism, quantify the precipitation-isotope change, or address
#' sediment-source change, depositional artifact, compound-source
#' mixing, age-model errors, evapotranspirative regime change, or
#' seasonality shifts (which `assess_claim()` gates with separate
#' fields). The calibration coefficients are derived from spatial
#' variation across sites; applying them to within-record temporal
#' vegetation change assumes the same response holds through time at
#' one location.
#'
#' @param oipc_ref Numeric scalar, the calibration-period `d2H_precip`
#'   at the site (per mil). Typically extracted from the OIPC raster
#'   (Bowen and Wilkinson 2002) at the site coordinates; the package
#'   does not bundle the raster. Held constant across the envelope by
#'   construction.
#' @param from Named numeric vector of fractional PFT cover at the
#'   baseline interval. Names must be exactly `tree`, `shrub`, `grass`,
#'   `C4` (case-sensitive). Values in \[0, 1\] with
#'   `tree + shrub + grass <= 1`; `C4` is an independent fraction.
#' @param to Named numeric vector of fractional PFT cover at the test
#'   interval. Same name and value constraints as `from`.
#' @param model_name Character, name of the calibration model to use.
#'   Must contain all eight PFT coefficients
#'   (`beta_{tree,shrub,grass,c4}` and
#'   `beta_oipc_x_{tree,shrub,grass,c4}`). Default
#'   `"full_interact_sp"` is the only shipped model that satisfies
#'   this requirement.
#' @param n_draws Integer, number of posterior draws to use. `NULL`
#'   (default) uses all available draws. Subsampling is deterministic
#'   (stratified, via [load_posteriors()]).
#' @param verbose Logical, whether to emit progress messages.
#'
#' @return List with
#'   \itemize{
#'     \item `envelope_draws` - numeric vector of per-draw signed
#'       envelopes (per mil).
#'     \item `envelope_median` - posterior median of `envelope_draws`.
#'     \item `envelope_p975_abs` -
#'       `quantile(abs(envelope_draws), 0.975)`, the absolute upper
#'       bound used by [assess_claim()] path (b).
#'     \item `oipc_ref` - the `oipc_ref` value used (echoed for
#'       traceability).
#'     \item `delta_pft` - named numeric vector `to - from`.
#'     \item `n_draws_used` - integer, number of draws contributing to
#'       `envelope_draws`.
#'     \item `model_name` - the model name used.
#'     \item `details` - list with `coefs_summary` (posterior median
#'       of each of the eight coefficients).
#'   }
#'
#' @section Manuscript reference:
#' Section 4.5.3 of the accompanying manuscript defines the
#' vegetation-only envelope and the constant-precipitation framing.
#' Section 4.5.6 places it in the Level 2 claim taxonomy.
#'
#' @export
#' @examples
#' \donttest{
#' # Hypothetical: a 30 percentage-point woody-to-grass transition at a
#' # site where the OIPC raster lookup gave d2H_precip approximately -60 per mil.
#' env <- compute_vegetation_envelope(
#'   oipc_ref = -60,
#'   from = c(tree = 0.4, shrub = 0.3, grass = 0.2, C4 = 0.05),
#'   to   = c(tree = 0.1, shrub = 0.2, grass = 0.5, C4 = 0.20),
#'   model_name = "full_interact_sp",
#'   n_draws = 100,
#'   verbose = FALSE
#' )
#' env$envelope_p975_abs   # absolute 97.5% upper bound of vegetation-only |Delta wax|
#' }
compute_vegetation_envelope <- function(oipc_ref,
                                        from,
                                        to,
                                        model_name = "full_interact_sp",
                                        n_draws = NULL,
                                        verbose = TRUE) {

  if (!is.numeric(oipc_ref) || length(oipc_ref) != 1L ||
      !is.finite(oipc_ref)) {
    stop("`oipc_ref` must be a single finite numeric value (per mil)",
         call. = FALSE)
  }
  .validate_pft_vector(from, "from")
  .validate_pft_vector(to,   "to")

  delta_pft <- to[REQUIRED_PFT_LABELS] - from[REQUIRED_PFT_LABELS]

  model <- load_posteriors(model_name, n_draws = n_draws,
                           verbose = verbose)
  draws <- model$draws
  param_names <- colnames(draws)

  # Resolve the eight required posterior columns through the friendly
  # PFT label -> Stan column map. Missing columns are an error with the
  # missing names listed; do not silently drop. [FIX-4]
  required_cols <- unlist(PFT_COEF_MAP)
  missing_cols  <- setdiff(required_cols, param_names)
  if (length(missing_cols) > 0L) {
    stop(sprintf(
      "model '%s' is missing required PFT coefficient column(s): %s. The vegetation envelope requires all four main effects and all four OIPC-by-PFT interactions; use a model that fits them (e.g., 'full_interact_sp').",
      model_name, paste(missing_cols, collapse = ", ")
    ), call. = FALSE)
  }

  beta_main <- vapply(REQUIRED_PFT_LABELS, function(k) {
    draws[[PFT_COEF_MAP[[k]][["main"]]]]
  }, numeric(nrow(draws)))
  beta_intr <- vapply(REQUIRED_PFT_LABELS, function(k) {
    draws[[PFT_COEF_MAP[[k]][["interaction"]]]]
  }, numeric(nrow(draws)))
  colnames(beta_main) <- REQUIRED_PFT_LABELS
  colnames(beta_intr) <- REQUIRED_PFT_LABELS

  # Per-draw envelope contributions (n_draws x 4), summed across PFT
  # classes. Vectorized: each row is one posterior draw, each column
  # one PFT class. `delta_pft` is recycled along rows by `*`. Manuscript
  # §4.5.3 formula:
  #   envelope = Σ_k β_k·ΔPFT_k + Σ_k β_oipc_x_k·oipc_ref·ΔPFT_k
  dv <- as.numeric(delta_pft[REQUIRED_PFT_LABELS])
  main_contrib <- sweep(beta_main, 2, dv, `*`)
  intr_contrib <- sweep(beta_intr * oipc_ref, 2, dv, `*`)
  envelope_draws <- rowSums(main_contrib) + rowSums(intr_contrib)

  envelope_p975_abs <- as.numeric(stats::quantile(
    abs(envelope_draws), 0.975, names = FALSE
  ))

  coefs_summary <- list(
    main_effect_medians = vapply(REQUIRED_PFT_LABELS, function(k) {
      stats::median(beta_main[, k])
    }, numeric(1L)),
    interaction_medians = vapply(REQUIRED_PFT_LABELS, function(k) {
      stats::median(beta_intr[, k])
    }, numeric(1L))
  )

  list(
    envelope_draws    = envelope_draws,
    envelope_median   = stats::median(envelope_draws),
    envelope_p975_abs = envelope_p975_abs,
    oipc_ref          = oipc_ref,
    delta_pft         = delta_pft,
    n_draws_used      = length(envelope_draws),
    model_name        = model_name,
    details           = list(coefs_summary = coefs_summary)
  )
}
