# R/model_ensemble.R

#' @importFrom stats median sd quantile setNames
NULL

#' Ensemble predictions across multiple models
#'
#' Runs \code{\link{invert_d2H}} against each model in `models` and
#' combines the per-draw reconstructions into a single pooled
#' posterior. Useful for downstream uncertainty estimates that should
#' span structural model uncertainty rather than condition on one
#' calibration variant.
#'
#' @param ... Arguments passed to \code{\link{invert_d2H}}.
#' @param models Character vector of v10 model names to include in the
#'   ensemble. Defaults to three structurally distinct variants:
#'   \code{full_sp} (all covariates + spatial GP), \code{full_interact_sp}
#'   (full + elevation x C4 interaction + spatial GP), and
#'   \code{elevation_c4_interact_sp} (elevation x C4 interaction with
#'   spatial GP, no PFT).
#' @param ensemble_method `"equal"` (default) pools per-draw
#'   reconstructions across models with equal weighting and returns a
#'   single resampled posterior. `"all"` returns the per-model results
#'   without pooling.
#' @return If `ensemble_method = "equal"`, a list with `posterior_draws`
#'   (pooled per-draw reconstructions), `ensemble_summary` (point-estimate
#'   summary statistics), `model_results` (the per-model output from
#'   `invert_d2H()` with `return_full = TRUE`), and `ensemble_method`.
#'   If `ensemble_method = "all"`, only `model_results` and
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

  # Pool the per-draw reconstructions across models. invert_d2H(...,
  # return_full = TRUE)$posterior_draws is an n_draws x n_locations
  # matrix; unlist() flattens these column-major into one vector per
  # model. Sample from the union to produce an ensemble posterior of
  # the same size as a single per-model posterior.
  all_draws <- unlist(lapply(results, function(x) x$posterior_draws))
  n_ensemble_draws <- length(results[[1]]$posterior_draws)
  combined_draws <- sample(all_draws, size = n_ensemble_draws, replace = TRUE)

  summary_stats <- list(
    mean = mean(combined_draws),
    median = median(combined_draws),
    sd = sd(combined_draws),
    ci_90 = quantile(combined_draws, c(0.05, 0.95)),
    ci_95 = quantile(combined_draws, c(0.025, 0.975)),
    n_models = length(models),
    models_used = models
  )

  return(list(
    posterior_draws = combined_draws,
    ensemble_summary = summary_stats,
    model_results = results,
    ensemble_method = ensemble_method
  ))
}