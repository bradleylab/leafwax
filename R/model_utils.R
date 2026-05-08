# R/model_utils.R - Model utility functions

#' Get available models
#'
#' Returns a list of all available calibration models for leaf wax hydrogen isotope
#' inversion. Models vary in their complexity and data requirements.
#'
#' @return Character vector of available model names. Models include:
#'   \itemize{
#'     \item \code{baseline}: Basic OIPC model without spatial effects
#'     \item \code{baseline_sp}: Basic model with spatial Gaussian process
#'     \item \code{baseline_env}: Includes elevation effects
#'     \item \code{baseline_env_sp}: Elevation effects with spatial GP
#'     \item \code{baseline_veg}: Includes vegetation (PFT) effects
#'     \item \code{baseline_veg_sp}: Vegetation effects with spatial GP
#'     \item \code{c4_only_sp}: C4 vegetation effects only (spatial)
#'     \item \code{elevation_only_sp}: Elevation effects only (spatial)
#'     \item \code{elevation_c4_sp}: Combined elevation and C4 effects
#'     \item \code{elevation_c4_interact_sp}: With interaction terms
#'     \item \code{full}: All effects without spatial component
#'     \item \code{full_sp}: All effects with spatial component
#'     \item \code{full_interact}: All effects with interactions
#'     \item \code{full_interact_sp}: Full model with spatial GP
#'   }
#' @examples
#' # List all available models
#' models <- available_models()
#' print(models)
#'
#' # Get details for a specific model
#' model_info <- get_model_parameters("baseline_sp")
#' print(model_info$description)
#' @export
available_models <- function() {
  # Return actual available model names
  return(list_model_names())
}

#' Get all model metadata
#'
#' Returns a list of all 14 models with their descriptions and properties.
#' The models are based on the spatial leafwax hierarchical Bayesian models.
#'
#' @return Named list of available models with metadata
#' @export
get_all_model_metadata <- function() {

  # Define all 14 models with their properties
  models <- list(
    # Basic models
    baseline = list(
      name = "baseline",
      description = "Basic OIPC model without spatial or environmental effects",
      has_spatial = FALSE,
      has_elevation = FALSE,
      has_c4 = FALSE,
      has_vegetation = FALSE,
      size_mb = 581
    ),

    baseline_sp = list(
      name = "baseline_sp",
      description = "Basic OIPC model with spatial Gaussian process",
      has_spatial = TRUE,
      has_elevation = FALSE,
      has_c4 = FALSE,
      has_vegetation = FALSE,
      size_mb = 917
    ),

    # Environmental models
    baseline_env = list(
      name = "baseline_env",
      description = "OIPC + elevation effects",
      has_spatial = FALSE,
      has_elevation = TRUE,
      has_c4 = FALSE,
      has_vegetation = FALSE,
      size_mb = 639
    ),

    baseline_env_sp = list(
      name = "baseline_env_sp",
      description = "OIPC + elevation + spatial effects",
      has_spatial = TRUE,
      has_elevation = TRUE,
      has_c4 = FALSE,
      has_vegetation = FALSE,
      size_mb = 992
    ),

    # Vegetation models
    baseline_veg = list(
      name = "baseline_veg",
      description = "OIPC + vegetation effects (C4/C3)",
      has_spatial = FALSE,
      has_elevation = FALSE,
      has_c4 = TRUE,
      has_vegetation = TRUE,
      size_mb = 717
    ),

    baseline_veg_sp = list(
      name = "baseline_veg_sp",
      description = "OIPC + vegetation + spatial effects",
      has_spatial = TRUE,
      has_elevation = FALSE,
      has_c4 = TRUE,
      has_vegetation = TRUE,
      size_mb = 1200
    ),

    # C4-specific models
    c4_only_sp = list(
      name = "c4_only_sp",
      description = "OIPC + C4 fraction + spatial effects",
      has_spatial = TRUE,
      has_elevation = FALSE,
      has_c4 = TRUE,
      has_vegetation = FALSE,
      size_mb = 986
    ),

    # Elevation models
    elevation_only_sp = list(
      name = "elevation_only_sp",
      description = "OIPC + elevation + spatial effects",
      has_spatial = TRUE,
      has_elevation = TRUE,
      has_c4 = FALSE,
      has_vegetation = FALSE,
      size_mb = 923
    ),

    elevation_c4_sp = list(
      name = "elevation_c4_sp",
      description = "OIPC + elevation + C4 + spatial effects",
      has_spatial = TRUE,
      has_elevation = TRUE,
      has_c4 = TRUE,
      has_vegetation = FALSE,
      size_mb = 992
    ),

    elevation_c4_interact_sp = list(
      name = "elevation_c4_interact_sp",
      description = "OIPC + elevation x C4 interaction + spatial effects",
      has_spatial = TRUE,
      has_elevation = TRUE,
      has_c4 = TRUE,
      has_vegetation = FALSE,
      has_interaction = TRUE,
      size_mb = 1300
    ),

    # Full models
    full = list(
      name = "full",
      description = "Full model with elevation + vegetation effects",
      has_spatial = FALSE,
      has_elevation = TRUE,
      has_c4 = TRUE,
      has_vegetation = TRUE,
      size_mb = 811
    ),

    full_sp = list(
      name = "full_sp",
      description = "Full model with all effects + spatial GP",
      has_spatial = TRUE,
      has_elevation = TRUE,
      has_c4 = TRUE,
      has_vegetation = TRUE,
      size_mb = 1700
    ),

    full_interact = list(
      name = "full_interact",
      description = "Full model with interactions (no spatial)",
      has_spatial = FALSE,
      has_elevation = TRUE,
      has_c4 = TRUE,
      has_vegetation = TRUE,
      has_interaction = TRUE,
      size_mb = 812
    ),

    full_interact_sp = list(
      name = "full_interact_sp",
      description = "Full model with all interactions + spatial GP",
      has_spatial = TRUE,
      has_elevation = TRUE,
      has_c4 = TRUE,
      has_vegetation = TRUE,
      has_interaction = TRUE,
      size_mb = 1700
    )
  )

  return(models)
}

#' List model names
#'
#' Returns the names of every model the package can resolve. Prefers
#' the heavy posteriors directory when present (development install),
#' otherwise falls back to the lightweight posteriors directory that
#' ships with every install. The user cache is intentionally not
#' enumerated here so the answer is stable regardless of what has been
#' downloaded.
#'
#' @return Character vector of model names. Empty if neither directory
#'   contains posterior files.
#' @export
list_model_names <- function() {
  for (subdir in c("posteriors", "posteriors_light")) {
    extdata_dir <- system.file("extdata", subdir, package = "leafwax")
    if (extdata_dir == "" || !dir.exists(extdata_dir)) {
      local_dir <- file.path("inst", "extdata", subdir)
      if (dir.exists(local_dir)) {
        extdata_dir <- local_dir
      } else {
        next
      }
    }
    files <- list.files(extdata_dir, pattern = "_posterior\\.rds$")
    if (length(files) > 0L) {
      return(gsub("_posterior\\.rds$", "", files))
    }
  }
  character(0)
}

#' Get model info
#'
#' @param model_name Name of the model
#' @return List with model metadata
#' @export
get_model_info <- function(model_name) {
  models <- get_all_model_metadata()

  if (!model_name %in% names(models)) {
    stop("Model '", model_name, "' not found. Available models: ",
         paste(available_models(), collapse = ", "))
  }

  return(models[[model_name]])
}

#' Select best model based on available data
#'
#' @param data Data frame with predictor variables
#' @return Recommended model name
#' @export
select_best_model <- function(data) {

  # Check what predictors are available
  has_elevation <- "elevation" %in% names(data)
  has_c4 <- any(c("c4_fraction", "c4_percent") %in% names(data))
  has_vegetation <- any(c("vegetation_type", "pft") %in% names(data))
  has_coords <- all(c("longitude", "latitude") %in% names(data))

  # Get available models to ensure we only recommend existing ones
  available <- available_models()

  # Select model based on available predictors (only return if available)
  if (has_elevation && has_c4 && has_vegetation && has_coords && "full_sp" %in% available) {
    return("full_sp")
  } else if (has_elevation && has_c4 && has_coords && "elevation_c4_sp" %in% available) {
    return("elevation_c4_sp")
  } else if (has_elevation && has_vegetation && has_coords && "baseline_env_sp" %in% available) {
    return("baseline_env_sp")  # Use env for elevation
  } else if (has_c4 && has_vegetation && has_coords && "baseline_veg_sp" %in% available) {
    return("baseline_veg_sp")
  } else if (has_elevation && has_coords && "elevation_only_sp" %in% available) {
    return("elevation_only_sp")
  } else if (has_c4 && has_coords && "c4_only_sp" %in% available) {
    return("c4_only_sp")
  } else if (has_coords && "baseline_sp" %in% available) {
    return("baseline_sp")
  } else if (has_elevation && has_c4 && "full" %in% available) {
    return("full")  # Non-spatial full model
  } else if (has_elevation && "baseline_env" %in% available) {
    return("baseline_env")
  } else if ((has_c4 || has_vegetation) && "baseline_veg" %in% available) {
    return("baseline_veg")
  } else if ("baseline" %in% available) {
    return("baseline")
  } else {
    # Return the first available model if nothing matches
    return(available[1])
  }
}