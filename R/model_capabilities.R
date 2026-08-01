# R/model_capabilities.R
#
# GENERATED FILE - do not edit by hand.
# Regenerate with: Rscript data-raw/generate_model_capabilities.R
# Source of truth: leafwax_working/config.yaml (model_configs).
#
# Per-model fitted capabilities, taken directly from the config flags that
# drove each fit (include_c4/pft/gp/elevation/precip/veg_interactions). This
# is authoritative for what a model *includes*; whether a given posterior
# deposit *carries* those coefficients is a separate, column-level question
# (see load_posteriors()).
#
# Elevation has THREE distinct questions, kept as distinct names to avoid the
# overloaded 'has_elevation':
#   * fitted_has_elevation (here)          - did the model FIT an elevation spline?
#   * metadata$has_elevation (load_posteriors) - does this DEPOSIT carry beta_elev cols?
#   * capabilities$has_elevation (model_compatibility) - does INVERSION consume elevation?
# fitted_has_elevation is documentation of the fit; no decision path reads it.
#
# The *_rfoff range_factor-off sensitivity variants are intentionally omitted:
# each shares its base model's covariate structure and thus its capabilities.
# model_capability() normalizes a trailing "_rfoff" to the base before lookup.

MODEL_CAPABILITIES <- list(
  `baseline` = list(has_c4 = FALSE, has_pft = FALSE, has_gp = FALSE, fitted_has_elevation = FALSE, has_precip = FALSE, has_interaction = FALSE, n_pp_knots = 0L),
  `baseline_veg` = list(has_c4 = TRUE, has_pft = TRUE, has_gp = FALSE, fitted_has_elevation = FALSE, has_precip = FALSE, has_interaction = TRUE, n_pp_knots = 0L),
  `baseline_env` = list(has_c4 = FALSE, has_pft = FALSE, has_gp = FALSE, fitted_has_elevation = TRUE, has_precip = TRUE, has_interaction = FALSE, n_pp_knots = 0L),
  `full` = list(has_c4 = TRUE, has_pft = TRUE, has_gp = FALSE, fitted_has_elevation = TRUE, has_precip = TRUE, has_interaction = FALSE, n_pp_knots = 0L),
  `full_interact` = list(has_c4 = TRUE, has_pft = TRUE, has_gp = FALSE, fitted_has_elevation = TRUE, has_precip = TRUE, has_interaction = TRUE, n_pp_knots = 0L),
  `baseline_sp` = list(has_c4 = FALSE, has_pft = FALSE, has_gp = TRUE, fitted_has_elevation = FALSE, has_precip = FALSE, has_interaction = FALSE, n_pp_knots = 125L),
  `baseline_veg_sp` = list(has_c4 = TRUE, has_pft = TRUE, has_gp = TRUE, fitted_has_elevation = FALSE, has_precip = FALSE, has_interaction = TRUE, n_pp_knots = 125L),
  `baseline_env_sp` = list(has_c4 = FALSE, has_pft = FALSE, has_gp = TRUE, fitted_has_elevation = TRUE, has_precip = TRUE, has_interaction = FALSE, n_pp_knots = 125L),
  `c4_only_sp` = list(has_c4 = TRUE, has_pft = FALSE, has_gp = TRUE, fitted_has_elevation = FALSE, has_precip = FALSE, has_interaction = FALSE, n_pp_knots = 125L),
  `elevation_only_sp` = list(has_c4 = FALSE, has_pft = FALSE, has_gp = TRUE, fitted_has_elevation = TRUE, has_precip = FALSE, has_interaction = FALSE, n_pp_knots = 125L),
  `elevation_c4_sp` = list(has_c4 = TRUE, has_pft = FALSE, has_gp = TRUE, fitted_has_elevation = TRUE, has_precip = FALSE, has_interaction = FALSE, n_pp_knots = 125L),
  `elevation_c4_interact_sp` = list(has_c4 = TRUE, has_pft = FALSE, has_gp = TRUE, fitted_has_elevation = TRUE, has_precip = FALSE, has_interaction = TRUE, n_pp_knots = 125L),
  `full_sp` = list(has_c4 = TRUE, has_pft = TRUE, has_gp = TRUE, fitted_has_elevation = TRUE, has_precip = TRUE, has_interaction = FALSE, n_pp_knots = 125L),
  `full_interact_sp` = list(has_c4 = TRUE, has_pft = TRUE, has_gp = TRUE, fitted_has_elevation = TRUE, has_precip = TRUE, has_interaction = TRUE, n_pp_knots = 125L)
)

#' Fitted capabilities for a model, from the config-derived manifest
#'
#' @param model_name Character model name (e.g. "full_sp"). A trailing
#'   "_rfoff" (range_factor-off sensitivity variant) is resolved to its base.
#' @return Named list of capability flags plus n_pp_knots.
#' @keywords internal
model_capability <- function(model_name) {
  key <- sub("_rfoff$", "", model_name)
  cap <- MODEL_CAPABILITIES[[key]]
  if (is.null(cap)) {
    stop("Unknown model '", model_name, "'. Known models: ",
         paste(names(MODEL_CAPABILITIES), collapse = ", "))
  }
  cap
}
