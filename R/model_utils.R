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
#'     \item \code{elevation_c4_interact_sp}: C4 effect + OIPC x C4 interaction (spatial; elevation spline fitted, not consumed by inversion)
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

  # Per-model human description + deposit size (MB). Capability flags are derived
  # from the config-derived manifest (MODEL_CAPABILITIES, generated from
  # config.yaml) so this catalog cannot drift from what each model was fitted
  # with. `has_vegetation` maps to the manifest's PFT flag.
  #
  # has_elevation is the exception: it is reported FALSE (same as
  # get_model_parameters). Several variants fit an elevation spline (see the
  # descriptions and MODEL_CAPABILITIES), but the Bayesian reconstruction
  # does not consume elevation, so the operative consumer flag is FALSE --
  # independent of whether the deposit carries beta_elev columns (chordal
  # deposits DO retain them). load_posteriors() reports the deposit-level value
  # from actual columns, which is deliberately distinct from this consumer flag.
  desc_size <- list(
    baseline                 = list("Basic OIPC model (no spatial or environmental effects)", 581),
    baseline_sp              = list("OIPC + spatial Gaussian process", 917),
    baseline_env             = list("OIPC + elevation spline + precipitation-amount effects", 639),
    baseline_env_sp          = list("OIPC + elevation spline + precipitation amount + spatial GP", 992),
    baseline_veg             = list("OIPC + C4 + PFT with OIPC x vegetation interactions", 717),
    baseline_veg_sp          = list("OIPC + C4 + PFT interactions + spatial GP", 1200),
    c4_only_sp               = list("OIPC + C4 fraction + spatial GP", 986),
    elevation_only_sp        = list("OIPC + elevation spline + spatial GP", 923),
    elevation_c4_sp          = list("OIPC + elevation spline + C4 + spatial GP", 992),
    elevation_c4_interact_sp = list("OIPC + elevation + C4 + OIPC x C4 interaction + spatial GP", 1300),
    full                     = list("OIPC + elevation + precipitation + C4 + PFT (main effects; no interactions)", 811),
    full_sp                  = list("OIPC + elevation + precipitation + C4 + PFT main effects + spatial GP", 1700),
    full_interact            = list("OIPC + elevation + precipitation + C4 + PFT with OIPC x vegetation interactions", 812),
    full_interact_sp         = list("OIPC + elevation + precipitation + C4 + PFT interactions + spatial GP", 1700)
  )

  models <- lapply(names(desc_size), function(name) {
    cap <- model_capability(name)
    ds  <- desc_size[[name]]
    list(
      name = name,
      description = ds[[1]],
      has_spatial = cap$has_gp,
      has_elevation = FALSE,   # consumer flag; see note above (fitted != consumed)
      has_precip = cap$has_precip,
      has_c4 = cap$has_c4,
      has_vegetation = cap$has_pft,
      has_interaction = cap$has_interaction,
      size_mb = ds[[2]]
    )
  })
  names(models) <- names(desc_size)

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
