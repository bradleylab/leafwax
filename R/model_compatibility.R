# R/model_compatibility.R - Model compatibility and parameter mapping

#' Get model parameters
#'
#' Returns which parameters each model expects and provides metadata
#' about model capabilities for validation.
#'
#' @param model_name Name of the model
#' @return List with model parameters and capabilities
#' @export
get_model_parameters <- function(model_name) {

  # Base parameters that all models have
  base_params <- c("beta_0", "beta_oipc", "sigma")

  # Initialize capabilities
  capabilities <- list(
    has_spatial = grepl("_sp$", model_name),
    has_elevation = grepl("(env|elevation)", model_name),
    has_c4 = grepl("(c4|veg)", model_name),
    has_pft = grepl("veg", model_name),
    has_interaction = grepl("interact", model_name)
  )

  # Expected parameters based on model type
  expected_params <- base_params

  if (capabilities$has_spatial) {
    expected_params <- c(expected_params, "lambda_decay", "effective_scale_km")
  }

  if (capabilities$has_elevation) {
    expected_params <- c(expected_params, "beta_elev")
  }

  if (capabilities$has_c4) {
    expected_params <- c(expected_params, "beta_c4")
  }

  if (capabilities$has_pft) {
    expected_params <- c(expected_params, "beta_tree", "beta_shrub", "beta_grass")
  }

  # Required predictors for this model
  required_predictors <- c("d2h_wax", "longitude", "latitude")

  if (capabilities$has_elevation) {
    required_predictors <- c(required_predictors, "elevation")
  }

  if (capabilities$has_c4 && !capabilities$has_pft) {
    required_predictors <- c(required_predictors, "c4_percent")
  }

  if (capabilities$has_pft) {
    required_predictors <- c(required_predictors, "pft_tree", "pft_shrub", "pft_grass")
  }

  return(list(
    model_name = model_name,
    capabilities = capabilities,
    expected_parameters = expected_params,
    required_predictors = required_predictors,
    knot_count = if (capabilities$has_spatial) 125 else 0,
    description = generate_model_description(model_name, capabilities)
  ))
}

#' Generate human-readable model description
#'
#' @param model_name Name of the model
#' @param capabilities Model capabilities list
#' @return Character description
#' @keywords internal
generate_model_description <- function(model_name, capabilities) {
  components <- c()

  if (capabilities$has_elevation) {
    components <- c(components, "elevation effects")
  }

  if (capabilities$has_c4 && !capabilities$has_pft) {
    components <- c(components, "C4 vegetation effects")
  }

  if (capabilities$has_pft) {
    components <- c(components, "plant functional type effects")
  }

  if (capabilities$has_interaction) {
    components <- c(components, "interaction effects")
  }

  if (capabilities$has_spatial) {
    components <- c(components, "spatial Gaussian process")
  }

  if (length(components) == 0) {
    return("Basic OIPC model")
  } else {
    return(paste("OIPC model with", paste(components, collapse = ", ")))
  }
}

#' Validate inputs for a specific model
#'
#' Checks that all required predictors are provided and warns about unused ones.
#'
#' @param model_name Name of the model
#' @param d2h_wax Leaf wax d2H values
#' @param longitude Longitude values
#' @param latitude Latitude values
#' @param elevation Elevation values (optional)
#' @param c4_percent C4 percentage values (optional)
#' @param pft_tree Tree PFT fraction (optional)
#' @param pft_shrub Shrub PFT fraction (optional)
#' @param pft_grass Grass PFT fraction (optional)
#' @param verbose Whether to print validation messages
#' @return List with validation results
#' @export
validate_model_inputs <- function(model_name, d2h_wax, longitude, latitude,
                                 elevation = NULL, c4_percent = NULL,
                                 pft_tree = NULL, pft_shrub = NULL, pft_grass = NULL,
                                 verbose = TRUE) {

  # Get model parameters
  model_info <- get_model_parameters(model_name)
  caps <- model_info$capabilities

  # Basic validation
  n_obs <- length(d2h_wax)
  errors <- c()
  warnings <- c()

  # Check coordinate dimensions
  if (length(longitude) != n_obs || length(latitude) != n_obs) {
    errors <- c(errors, "All input vectors must have the same length")
  }

  # Check required predictors
  if (caps$has_elevation && is.null(elevation)) {
    warnings <- c(warnings, paste("Model", model_name, "expects elevation but none provided"))
  }

  if (caps$has_c4 && !caps$has_pft && is.null(c4_percent)) {
    warnings <- c(warnings, paste("Model", model_name, "expects C4 percentage but none provided"))
  }

  if (caps$has_pft && (is.null(pft_tree) || is.null(pft_shrub) || is.null(pft_grass))) {
    warnings <- c(warnings, paste("Model", model_name, "expects PFT fractions but some are missing"))
  }

  # Check for unnecessary predictors
  if (!caps$has_elevation && !is.null(elevation)) {
    warnings <- c(warnings, paste("Elevation provided but model", model_name, "does not include elevation effects"))
  }

  if (!caps$has_c4 && !is.null(c4_percent)) {
    warnings <- c(warnings, paste("C4 percentage provided but model", model_name, "does not include C4 effects"))
  }

  if (!caps$has_pft && (!is.null(pft_tree) || !is.null(pft_shrub) || !is.null(pft_grass))) {
    warnings <- c(warnings, paste("PFT fractions provided but model", model_name, "does not include PFT effects"))
  }

  # Print messages if verbose
  if (verbose) {
    if (length(errors) > 0) {
      cat("ERRORS:\n")
      for (err in errors) cat("  -", err, "\n")
    }

    if (length(warnings) > 0) {
      cat("WARNINGS:\n")
      for (warn in warnings) cat("  -", warn, "\n")
    }

    if (length(errors) == 0 && length(warnings) == 0) {
      cat("✓ All inputs valid for model:", model_name, "\n")
    }
  }

  return(list(
    valid = length(errors) == 0,
    errors = errors,
    warnings = warnings,
    model_info = model_info
  ))
}

#' Get model recommendations based on available data
#'
#' Suggests the best model(s) to use given the available predictors.
#'
#' @param has_elevation Whether elevation data is available
#' @param has_c4 Whether C4 vegetation data is available
#' @param has_pft Whether PFT data is available
#' @param prefer_spatial Whether to prefer spatial models
#' @param available_models Vector of available model names (optional)
#' @return Ranked list of recommended models
#' @export
get_model_recommendations <- function(has_elevation = FALSE, has_c4 = FALSE, has_pft = FALSE,
                                    prefer_spatial = TRUE, available_models = NULL) {

  if (is.null(available_models)) {
    available_models <- available_models()
  }

  recommendations <- list()

  for (model in available_models) {
    model_info <- get_model_parameters(model)
    caps <- model_info$capabilities

    # Calculate compatibility score
    score <- 0

    # Base compatibility
    score <- score + 10

    # Bonus for using available predictors
    if (has_elevation && caps$has_elevation) score <- score + 20
    if (has_c4 && caps$has_c4) score <- score + 15
    if (has_pft && caps$has_pft) score <- score + 15

    # Bonus for spatial models if preferred
    if (prefer_spatial && caps$has_spatial) score <- score + 10

    # Penalty for requiring unavailable predictors
    if (caps$has_elevation && !has_elevation) score <- score - 50
    if (caps$has_c4 && !has_c4 && !caps$has_pft) score <- score - 30
    if (caps$has_pft && !has_pft) score <- score - 40

    recommendations[[model]] <- list(
      model_name = model,
      score = score,
      description = model_info$description,
      compatible = score > 0
    )
  }

  # Sort by score (descending)
  recommendations <- recommendations[order(sapply(recommendations, function(x) x$score), decreasing = TRUE)]

  # Filter to only compatible models
  compatible_models <- recommendations[sapply(recommendations, function(x) x$compatible)]

  return(compatible_models)
}