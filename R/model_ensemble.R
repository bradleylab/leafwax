# R/model_ensemble.R

#' @importFrom stats median sd quantile setNames
NULL

#' Ensemble predictions across multiple models
#'
#' Runs \code{\link{invert_d2H}} against each model in `models` and
#' combines the per-draw reconstructions per site, preserving the
#' per-site dimension. Useful for downstream uncertainty estimates
#' that should span structural model uncertainty rather than condition
#' on one calibration variant.
#'
#' @param ... Arguments passed to \code{\link{invert_d2H}} (e.g.,
#'   `d2H_wax`, `d2H_wax_sd`, `longitude`, `latitude`, optional
#'   covariates).
#' @param models Character vector of v10 model names to include in the
#'   ensemble. Defaults to three structurally distinct variants:
#'   \code{full_sp} (all covariates + spatial GP), \code{full_interact_sp}
#'   (full + elevation x C4 interaction + spatial GP), and
#'   \code{elevation_c4_interact_sp} (elevation x C4 interaction with
#'   spatial GP, no PFT).
#' @param ensemble_method `"equal"` (default) pools per-draw
#'   reconstructions per site across models with equal weighting and
#'   returns a per-site posterior. `"all"` returns the per-model
#'   results without pooling.
#' @return If `ensemble_method = "equal"`, a list with:
#'   `posterior_draws` (an `n_draws x n_sites` matrix of pooled
#'   per-site, per-draw reconstructions), `ensemble_summary` (a
#'   data frame with one row per site: `mean`, `median`, `sd`,
#'   `ci_90_lower`/`ci_90_upper`, `ci_95_lower`/`ci_95_upper`,
#'   `n_models_used`), `model_results` (the per-model output from
#'   `invert_d2H()` with `return_full = TRUE`), `models_used` (the
#'   models actually pooled), and `ensemble_method`. If
#'   `ensemble_method = "all"`, only `model_results` and
#'   `ensemble_method` are returned.
#' @export
invert_d2H_ensemble <- function(...,
                                models = c("full_sp",
                                           "full_interact_sp",
                                           "elevation_c4_interact_sp"),
                                ensemble_method = c("equal", "all")) {

  ensemble_method <- match.arg(ensemble_method)

  # available_models() returns a character vector of model names, not
  # a data frame; the previous $model accessor was always NULL.
  all_models <- available_models()

  invalid_models <- models[!models %in% all_models]
  if (length(invalid_models) > 0) {
    stop("Invalid models: ", paste(invalid_models, collapse = ", "),
         ". Use available_models() to see options.")
  }

  # invert_d2H() defaults to return_full = FALSE (a summary data frame
  # with no $posterior_draws slot). The ensemble pool requires per-draw
  # reconstructions, so force return_full = TRUE here.
  results <- list()
  for (model in models) {
    cat("Running model:", model, "\n")
    results[[model]] <- invert_d2H(..., model_name = model,
                                   return_full = TRUE)
  }

  if (ensemble_method == "all") {
    return(list(
      model_results = results,
      ensemble_method = ensemble_method
    ))
  }

  # Coerce each model's `posterior_draws` to an n_draws x n_sites
  # matrix and verify shapes are consistent across models. invert_d2H()
  # may return either a vector (single-site) or a matrix (multi-site)
  # depending on the inversion path; standardise here so the per-site
  # pool below has a stable shape.
  draws_list <- lapply(results, function(x) {
    pd <- x$posterior_draws
    if (is.null(dim(pd))) pd <- matrix(pd, ncol = 1L)
    pd
  })
  n_draws_per_model <- vapply(draws_list, nrow, integer(1))
  n_sites_per_model <- vapply(draws_list, ncol, integer(1))

  if (length(unique(n_sites_per_model)) != 1L) {
    stop("Per-model posterior matrices disagree on n_sites: ",
         paste(n_sites_per_model, collapse = ", "),
         ". This should not happen for a single shared input vector.")
  }
  n_sites <- n_sites_per_model[[1]]

  # Pool per-site, per-draw across models with equal weighting. For
  # each site, concatenate the per-model draws into one bag of length
  # sum(n_draws_per_model), then resample n_target draws (n_target =
  # the first model's n_draws, so the output dimension matches a
  # single-model run).
  n_target <- n_draws_per_model[[1]]
  pooled <- matrix(NA_real_, nrow = n_target, ncol = n_sites)
  for (site_idx in seq_len(n_sites)) {
    bag <- unlist(lapply(draws_list, function(m) m[, site_idx]))
    pooled[, site_idx] <- sample(bag, size = n_target, replace = TRUE)
  }

  # Per-site point-estimate summary. Each column of `pooled` is the
  # posterior at one site after model pooling.
  summary_per_site <- data.frame(
    mean         = apply(pooled, 2, mean,   na.rm = TRUE),
    median       = apply(pooled, 2, median, na.rm = TRUE),
    sd           = apply(pooled, 2, sd,     na.rm = TRUE),
    ci_90_lower  = apply(pooled, 2, quantile, probs = 0.05,  na.rm = TRUE),
    ci_90_upper  = apply(pooled, 2, quantile, probs = 0.95,  na.rm = TRUE),
    ci_95_lower  = apply(pooled, 2, quantile, probs = 0.025, na.rm = TRUE),
    ci_95_upper  = apply(pooled, 2, quantile, probs = 0.975, na.rm = TRUE),
    n_models_used = length(models),
    stringsAsFactors = FALSE
  )

  return(list(
    posterior_draws  = pooled,
    ensemble_summary = summary_per_site,
    model_results    = results,
    models_used      = models,
    ensemble_method  = ensemble_method
  ))
}