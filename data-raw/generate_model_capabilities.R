# data-raw/generate_model_capabilities.R
#
# Regenerate R/model_capabilities.R from the analysis pipeline's config.yaml,
# which is the SINGLE SOURCE OF TRUTH for each model's fitted capabilities.
# The former name-regex capability derivation mislabeled `full`/`full_sp` as
# interaction models (config: include_veg_interactions = false) and hardcoded
# has_elevation = FALSE. This manifest replaces that guesswork with the config.
#
# Run from the package root (with the analysis repo colocated):
#   Rscript data-raw/generate_model_capabilities.R

library(yaml)

cfg_path <- "../leafwax_working/config.yaml"
if (!file.exists(cfg_path)) {
  stop("config.yaml not found at '", cfg_path, "'. Run from the leafwax-pkg root ",
       "with the leafwax_working analysis repo colocated.")
}
cfg <- yaml::read_yaml(cfg_path)
mc <- cfg$model_configs
if (is.null(mc) || !length(mc)) stop("No model_configs found in config.yaml")

# Exclude the *_rfoff range_factor-off sensitivity variants. Each is a clone of
# its base model (baseline_sp, baseline_env_sp, full_interact_sp) differing ONLY
# in the apply_range_factor regularization knob — the covariate structure, and
# therefore every capability flag, is identical to the base. They are sensitivity
# fits, not release models, so they get no distinct capability entry;
# model_capability() normalizes a trailing "_rfoff" to the base before lookup.
# Without this filter, re-running the generator would silently add 3 entries and
# drift from the committed manifest.
rfoff <- grepl("_rfoff$", names(mc))
if (any(rfoff)) {
  message("Excluding ", sum(rfoff), " *_rfoff sensitivity variant(s): ",
          paste(names(mc)[rfoff], collapse = ", "))
  mc <- mc[!rfoff]
}

flag <- function(x) isTRUE(x)
knots <- function(x) if (is.null(x)) 0L else as.integer(x)

entries <- vapply(names(mc), function(nm) {
  m <- mc[[nm]]
  sprintf(
    paste0("  `%s` = list(has_c4 = %s, has_pft = %s, has_gp = %s, ",
           "fitted_has_elevation = %s, has_precip = %s, has_interaction = %s, ",
           "n_pp_knots = %dL)"),
    nm,
    flag(m$include_c4), flag(m$include_pft), flag(m$include_gp),
    flag(m$include_elevation), flag(m$include_precip),
    flag(m$include_veg_interactions), knots(m$n_pp_knots))
}, character(1))

header <- c(
  "# R/model_capabilities.R",
  "#",
  "# GENERATED FILE - do not edit by hand.",
  "# Regenerate with: Rscript data-raw/generate_model_capabilities.R",
  "# Source of truth: leafwax_working/config.yaml (model_configs).",
  "#",
  "# Per-model fitted capabilities, taken directly from the config flags that",
  "# drove each fit (include_c4/pft/gp/elevation/precip/veg_interactions). This",
  "# is authoritative for what a model *includes*; whether a given posterior",
  "# deposit *carries* those coefficients is a separate, column-level question",
  "# (see load_posteriors()).",
  "#",
  "# Elevation has THREE distinct questions, kept as distinct names to avoid the",
  "# overloaded 'has_elevation':",
  "#   * fitted_has_elevation (here)          - did the model FIT an elevation spline?",
  "#   * metadata$has_elevation (load_posteriors) - does this DEPOSIT carry beta_elev cols?",
  "#   * capabilities$has_elevation (model_compatibility) - does INVERSION consume elevation?",
  "# fitted_has_elevation is documentation of the fit; no decision path reads it.",
  "#",
  "# The *_rfoff range_factor-off sensitivity variants are intentionally omitted:",
  "# each shares its base model's covariate structure and thus its capabilities.",
  "# model_capability() normalizes a trailing \"_rfoff\" to the base before lookup.",
  "",
  "MODEL_CAPABILITIES <- list(",
  paste(entries, collapse = ",\n"),
  ")",
  "",
  "#' Fitted capabilities for a model, from the config-derived manifest",
  "#'",
  "#' @param model_name Character model name (e.g. \"full_sp\"). A trailing",
  "#'   \"_rfoff\" (range_factor-off sensitivity variant) is resolved to its base.",
  "#' @return Named list of capability flags plus n_pp_knots.",
  "#' @keywords internal",
  "model_capability <- function(model_name) {",
  "  key <- sub(\"_rfoff$\", \"\", model_name)",
  "  cap <- MODEL_CAPABILITIES[[key]]",
  "  if (is.null(cap)) {",
  "    stop(\"Unknown model '\", model_name, \"'. Known models: \",",
  "         paste(names(MODEL_CAPABILITIES), collapse = \", \"))",
  "  }",
  "  cap",
  "}"
)

out <- "R/model_capabilities.R"
writeLines(header, out)
cat("Wrote", out, "with", length(mc), "models:\n  ",
    paste(names(mc), collapse = ", "), "\n")
