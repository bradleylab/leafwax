#' leafwax: Bayesian Calibration of Leaf Wax Hydrogen Isotope Reconstructions
#'
#' @description
#' The leafwax package provides tools for probabilistic inversion of leaf wax
#' hydrogen isotope measurements (delta-2-H) to reconstruct precipitation isotope values.
#' It implements hierarchical Bayesian models that account for multiple sources of
#' uncertainty including measurement error, biological fractionation, and spatial
#' correlation in isotope patterns.
#'
#' @section Main Functions:
#' \describe{
#'   \item{\code{\link{invert_d2H}}}{Bayesian inversion of leaf wax delta2H to precipitation delta2H}
#'   \item{\code{\link{available_models}}}{List all available calibration models}
#'   \item{\code{\link{load_posteriors}}}{Load posterior distributions for a specific model}
#'   \item{\code{\link{get_model_parameters}}}{Get model capabilities and required parameters}
#'   \item{\code{\link{validate_model_inputs}}}{Validate inputs for a specific model}
#' }
#'
#' @section Available Models:
#' The package includes 14 calibration models with different capabilities. The
#' v10 fits include precipitation amount (\code{baseline_env*} and
#' \code{full*} variants), C4 abundance, and PFT cover; none of the v10
#' variants carry a fitted elevation coefficient despite the historical
#' "elevation_*" naming. Runtime capability flags in
#' \code{load_posteriors()} are derived from each model's posterior
#' columns at load time.
#' \itemize{
#'   \item \strong{Basic models}: baseline, baseline_sp
#'   \item \strong{Precipitation models}: baseline_env, baseline_env_sp
#'   \item \strong{Vegetation models}: baseline_veg, baseline_veg_sp, c4_only_sp
#'   \item \strong{Combined spatial models}: elevation_only_sp,
#'     elevation_c4_sp, elevation_c4_interact_sp
#'   \item \strong{Full models}: full, full_sp, full_interact, full_interact_sp
#' }
#'
#' Models with "_sp" suffix use spatial Gaussian processes with 125 knots on a
#' Fibonacci sphere lattice for improved uncertainty quantification.
#'
#' @section Model Selection:
#' Pass \code{model = "auto"} to \code{predict_d2h_precip()} to let
#' \code{select_best_model_from_flags()} choose a model based on which
#' covariates the caller has supplied; otherwise pick a model name from
#' \code{available_models()} explicitly.
#'
#' @section Key Features:
#' \itemize{
#'   \item Hierarchical Bayesian framework for uncertainty propagation
#'   \item Support for single and multi-location inversions
#'   \item Spatial correlation via Gaussian processes
#'   \item Automatic handling of missing covariates
#' }
#'
#' @references
#' Bowen, G. J., Cai, Z., Fiorella, R. P., & Putman, A. L. (2019).
#' Isotopes in the water cycle: Regional-to global-scale patterns and applications.
#' Annual Review of Earth and Planetary Sciences, 47, 453-479.
#' \doi{10.1146/annurev-earth-053018-060220}
#'
#' Sachse, D., Billault, I., Bowen, G. J., Chikaraishi, Y., Dawson, T. E., Feakins, S. J., ... & Kahmen, A. (2012).
#' Molecular paleohydrology: Interpreting the hydrogen-isotopic composition of lipid biomarkers from photosynthesizing organisms.
#' Annual Review of Earth and Planetary Sciences, 40, 221-249.
#' \doi{10.1146/annurev-earth-042711-105535}
#'
#' Bradley, A. (2026). leafwax v10 model posteriors.
#' Zenodo DOI \doi{10.5281/zenodo.20085465}.
#'
#' @examples
#' local({
#'   old <- options(leafwax.suppress_preview_warning = TRUE)
#'   on.exit(options(old))
#'
#'   # List available models
#'   models <- available_models()
#'   n_models <- length(models)
#'
#'   # Simple single-location inversion
#'   result <- invert_d2H(
#'     d2H_wax = -150,
#'     d2H_wax_sd = 3,
#'     longitude = -120,
#'     latitude = 40,
#'     model_name = "baseline",
#'     verbose = FALSE
#'   )
#' })
#'
#' @keywords internal
#' @importFrom jsonlite fromJSON
#' @importFrom stats rnorm quantile sd median runif cor aggregate
#' @importFrom utils read.csv write.csv data setTxtProgressBar txtProgressBar
"_PACKAGE"
