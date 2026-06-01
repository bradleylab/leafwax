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
  # reconstructions, so force return_full = TRUE here. Strip any
  # caller-supplied return_full / model_name from `...` first — both
  # are controlled by this function and a duplicate via `...` would
  # error with "matched by multiple actual arguments".
  extra_args <- list(...)
  extra_args[c("return_full", "model_name")] <- NULL

  results <- list()
  for (model in models) {
    message("Running model: ", model)
    results[[model]] <- do.call(invert_d2H, c(
      extra_args,
      list(model_name = model, return_full = TRUE)
    ))
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

  # Pool per-site, per-draw across models with equal weighting.
  # Naively concatenating each model's per-site draws and then
  # resampling biases the pool toward the model with the most draws
  # (e.g., a 1000-draw heavy posterior contributes 10x more samples
  # than a 100-draw preview-tier model). Instead, resample each model
  # to a uniform `per_model` count first, then concatenate. The total
  # pool size matches the median draw count across models, so a single
  # outlier (one preview-tier model in a heavy ensemble) does not
  # silently shrink the pool to its fixture size.
  k <- length(draws_list)
  if (length(unique(n_draws_per_model)) != 1L) {
    warning(sprintf(
      "Ensemble models have unequal draw counts (%s); pooling each to the median (%d) before equal-weight combination. Mixed-tier ensembles can lose draws relative to a uniform-tier run.",
      paste(n_draws_per_model, collapse = ", "),
      stats::median(n_draws_per_model)
    ), call. = FALSE)
  }
  n_target <- as.integer(stats::median(n_draws_per_model))
  per_model <- floor(n_target / k)
  remainder <- n_target - per_model * k
  pooled <- matrix(NA_real_, nrow = n_target, ncol = n_sites)
  for (site_idx in seq_len(n_sites)) {
    chunks <- lapply(draws_list, function(m) {
      sample(m[, site_idx], size = per_model, replace = TRUE)
    })
    bag <- unlist(chunks, use.names = FALSE)
    if (remainder > 0L) {
      # Distribute the remainder across models so the pool is exactly
      # n_target and weighting stays as close to equal as possible.
      extras <- sample(seq_len(k), size = remainder, replace = FALSE)
      for (j in extras) {
        bag <- c(bag, sample(draws_list[[j]][, site_idx], size = 1L,
                             replace = TRUE))
      }
    }
    pooled[, site_idx] <- bag
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
