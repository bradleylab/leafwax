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
#' @param models Explicit character vector of compatible Bayesian-inversion
#'   model names. There is no scientific default ensemble.
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
                                models = NULL,
                                ensemble_method = c("equal", "all")) {

  ensemble_method <- match.arg(ensemble_method)
  if (is.null(models) || !length(models)) {
    stop("models must be supplied explicitly; no default scientific ensemble is defined.",
         call. = FALSE)
  }
  invalid_models <- setdiff(models, .supported_bayesian_inverse_models)
  if (length(invalid_models)) {
    stop(
      "Unsupported Bayesian-inversion ensemble model(s): ",
      paste(invalid_models, collapse = ", "),
      ". Compatible models are: ",
      paste(.supported_bayesian_inverse_models, collapse = ", "), ".",
      call. = FALSE
    )
  }
  extra_args <- list(...)
  extra_args[c("return_full", "model_name")] <- NULL
  if (is.null(extra_args$prior)) {
    stop("A proper prior must be supplied explicitly to the ensemble.",
         call. = FALSE)
  }
  if (is.null(extra_args$n_inverse_samples) ||
      extra_args$n_inverse_samples <= 0L || is.null(extra_args$seed)) {
    stop("The ensemble requires positive n_inverse_samples and an explicit seed.",
         call. = FALSE)
  }
  base_seed <- as.integer(extra_args$seed)

  results <- list()
  for (model_index in seq_along(models)) {
    model <- models[[model_index]]
    model_args <- extra_args
    model_args$seed <- base_seed + model_index - 1L
    results[[model]] <- do.call(invert_d2H, c(
      model_args,
      list(model_name = model, return_full = TRUE)
    ))
  }

  if (ensemble_method == "all") {
    return(list(
      model_results = results,
      ensemble_method = ensemble_method
    ))
  }

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

  if (length(unique(n_draws_per_model)) != 1L) {
    stop("Compatible ensemble inversions returned unequal sample counts.",
         call. = FALSE)
  }
  pooled <- do.call(rbind, draws_list)

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

  structure(list(
    status = if (all(vapply(results, function(x) x$status == "ok", logical(1))))
      "ok" else "inconclusive",
    posterior_draws = pooled,
    ensemble_summary = summary_per_site,
    model_results = results,
    models_used = models,
    ensemble_method = ensemble_method,
    metadata = list(
      weighting = "equal model weights by equal sample counts",
      model_seeds = stats::setNames(base_seed + seq_along(models) - 1L, models)
    )
  ), class = "leafwax_inverse_ensemble")
}
