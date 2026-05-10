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
#'     \item \code{baseline_env}: Includes precipitation-amount effects
#'     \item \code{baseline_env_sp}: Precipitation-amount effects with spatial GP
#'     \item \code{baseline_veg}: Includes vegetation interaction effects
#'     \item \code{baseline_veg_sp}: Vegetation interactions with spatial GP
#'     \item \code{c4_only_sp}: C4 vegetation effects only (spatial)
#'     \item \code{elevation_only_sp}: Historical elevation-context variant (spatial)
#'     \item \code{elevation_c4_sp}: Historical elevation-context + C4 variant
#'     \item \code{elevation_c4_interact_sp}: Historical elevation/C4-interaction name; C4 effect only
#'     \item \code{full}: Precipitation amount + vegetation interactions without spatial component
#'     \item \code{full_sp}: Precipitation amount + vegetation interactions with spatial component
#'     \item \code{full_interact}: Precipitation amount + vegetation interactions
#'     \item \code{full_interact_sp}: Full interaction model with spatial GP
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

  # Define all 14 models with their v10 fitted capabilities. The v10
  # posteriors do not contain beta_elev columns, so has_elevation is
  # FALSE for every shipped model even when the historical model id
  # contains "elevation".
  model_meta <- function(name, description,
                         has_spatial = FALSE,
                         has_precip = FALSE,
                         has_c4 = FALSE,
                         has_vegetation = FALSE,
                         has_interaction = FALSE,
                         size_mb = NA_real_) {
    list(
      name = name,
      description = description,
      has_spatial = has_spatial,
      has_elevation = FALSE,
      has_precip = has_precip,
      has_c4 = has_c4,
      has_vegetation = has_vegetation,
      has_interaction = has_interaction,
      size_mb = size_mb
    )
  }

  models <- list(
    baseline = model_meta(
      "baseline",
      "Basic OIPC model without spatial or environmental effects",
      size_mb = 581
    ),

    baseline_sp = model_meta(
      "baseline_sp",
      "Basic OIPC model with spatial Gaussian process",
      has_spatial = TRUE,
      size_mb = 917
    ),

    baseline_env = model_meta(
      "baseline_env",
      "OIPC + precipitation-amount effect",
      has_precip = TRUE,
      size_mb = 639
    ),

    baseline_env_sp = model_meta(
      "baseline_env_sp",
      "OIPC + precipitation-amount + spatial effects",
      has_spatial = TRUE,
      has_precip = TRUE,
      size_mb = 992
    ),

    baseline_veg = model_meta(
      "baseline_veg",
      "OIPC + vegetation interaction effects (C4/PFT)",
      has_c4 = TRUE,
      has_vegetation = TRUE,
      has_interaction = TRUE,
      size_mb = 717
    ),

    baseline_veg_sp = model_meta(
      "baseline_veg_sp",
      "OIPC + vegetation interactions + spatial effects",
      has_spatial = TRUE,
      has_c4 = TRUE,
      has_vegetation = TRUE,
      has_interaction = TRUE,
      size_mb = 1200
    ),

    c4_only_sp = model_meta(
      "c4_only_sp",
      "OIPC + C4 fraction + spatial effects",
      has_spatial = TRUE,
      has_c4 = TRUE,
      size_mb = 986
    ),

    elevation_only_sp = model_meta(
      "elevation_only_sp",
      "OIPC + spatial effects (historical elevation-context variant; no fitted elevation coefficient)",
      has_spatial = TRUE,
      size_mb = 923
    ),

    elevation_c4_sp = model_meta(
      "elevation_c4_sp",
      "OIPC + C4 + spatial effects (historical elevation-context variant)",
      has_spatial = TRUE,
      has_c4 = TRUE,
      size_mb = 992
    ),

    elevation_c4_interact_sp = model_meta(
      "elevation_c4_interact_sp",
      "OIPC + C4 + spatial effects (historical elevation/interaction-context variant; no fitted elevation or interaction coefficient)",
      has_spatial = TRUE,
      has_c4 = TRUE,
      size_mb = 1300
    ),

    full = model_meta(
      "full",
      "Precipitation amount + vegetation interactions",
      has_precip = TRUE,
      has_c4 = TRUE,
      has_vegetation = TRUE,
      has_interaction = TRUE,
      size_mb = 811
    ),

    full_sp = model_meta(
      "full_sp",
      "Precipitation amount + vegetation interactions + spatial GP",
      has_spatial = TRUE,
      has_precip = TRUE,
      has_c4 = TRUE,
      has_vegetation = TRUE,
      has_interaction = TRUE,
      size_mb = 1700
    ),

    full_interact = model_meta(
      "full_interact",
      "Precipitation amount + vegetation interactions (no spatial GP)",
      has_precip = TRUE,
      has_c4 = TRUE,
      has_vegetation = TRUE,
      has_interaction = TRUE,
      size_mb = 812
    ),

    full_interact_sp = model_meta(
      "full_interact_sp",
      "Precipitation amount + vegetation interactions + spatial GP",
      has_spatial = TRUE,
      has_precip = TRUE,
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
