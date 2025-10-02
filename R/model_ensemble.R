# R/model_ensemble.R

#' @importFrom stats median sd quantile setNames
NULL

#' Ensemble predictions across multiple models
#' 
#' @param ... Arguments passed to \code{\link{invert_d2H}}
#' @param models Character vector of model names to include in ensemble
#' @param ensemble_method Method for combining models: "equal" or "all"
#' @return List with ensemble predictions and individual model results
#' @export
invert_d2H_ensemble <- function(..., 
                               models = c("b0b1_elev_c4_pft_sp", "b0b1_elev_c4_sp", "b0b1_elev_pft_sp"),
                               ensemble_method = c("equal", "all")) {
  
  ensemble_method <- match.arg(ensemble_method)
  
  # Get available models
  all_models <- available_models()$model
  
  # Validate requested models
  invalid_models <- models[!models %in% all_models]
  if (length(invalid_models) > 0) {
    stop("Invalid models: ", paste(invalid_models, collapse = ", "), 
         ". Use available_models() to see options.")
  }
  
  # Get predictions from each model
  results <- list()
  for (model in models) {
    cat("Running model:", model, "\n")
    results[[model]] <- invert_d2H(..., model_name = model)
  }
  
  if (ensemble_method == "all") {
    # Return all model results
    return(list(
      model_results = results,
      ensemble_method = ensemble_method
    ))
  } else if (ensemble_method == "equal") {
    # Equal weighting
    weights <- rep(1/length(models), length(models))
  }
  
  # Combine posteriors
  all_draws <- unlist(lapply(results, function(x) x$posterior_draws))
  
  # Sample from combined draws
  n_ensemble_draws <- length(results[[1]]$posterior_draws)
  combined_draws <- sample(all_draws, size = n_ensemble_draws, replace = TRUE)
  
  # Compute ensemble summary
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