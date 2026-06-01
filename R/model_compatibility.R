# R/model_compatibility.R - Model compatibility and parameter metadata

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
  base_params <- c("beta_0", "beta_d2Hp", "sigma")

  # Initialize capabilities. The v10 fits did not produce beta_elev
  # coefficients despite the historical "elevation_*" / "env" naming;
  # has_elevation is therefore FALSE for every v10 model. The "env"
  # variants instead carry a beta_precip term (precipitation amount),
  # exposed here as has_precip. Capability flags stay name-based so this
  # function is callable without loading the posterior; load_posteriors()
  # cross-checks the actual columns at load time.
  capabilities <- list(
    has_spatial = grepl("_sp$", model_name),
    has_elevation = FALSE,
    has_precip = grepl("env", model_name) || grepl("^full", model_name),
    has_c4 = grepl("(c4|veg|^full)", model_name),
    has_pft = grepl("(veg|^full)", model_name),
    has_interaction = grepl("(veg|^full)", model_name)
  )

  # Expected parameters based on model type
  expected_params <- base_params

  if (capabilities$has_spatial) {
    expected_params <- c(expected_params, "lambda_decay", "effective_scale_km")
  }

  if (capabilities$has_precip) {
    expected_params <- c(expected_params, "beta_precip")
  }

  if (capabilities$has_c4) {
    expected_params <- c(expected_params, "beta_c4")
  }

  if (capabilities$has_pft) {
    expected_params <- c(expected_params, "beta_tree", "beta_shrub", "beta_grass")
  }

  if (capabilities$has_interaction) {
    if (capabilities$has_c4) {
      expected_params <- c(expected_params, "beta_d2Hp_x_c4")
    }
    if (capabilities$has_pft) {
      expected_params <- c(
        expected_params,
        "beta_d2Hp_x_tree", "beta_d2Hp_x_shrub", "beta_d2Hp_x_grass"
      )
    }
  }

  # Required predictors for this model
  required_predictors <- c("d2h_wax", "longitude", "latitude")

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
    knot_count = if (capabilities$has_spatial) N_SPATIAL_KNOTS else 0L,
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

  if (isTRUE(capabilities$has_precip)) {
    components <- c(components, "precipitation-amount effects")
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
      cat("[OK] All inputs valid for model:", model_name, "\n")
    }
  }

  return(list(
    valid = length(errors) == 0,
    errors = errors,
    warnings = warnings,
    model_info = model_info
  ))
}
