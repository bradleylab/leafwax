#' leafwax: Bayesian Calibration of Leaf Wax Hydrogen Isotope Reconstructions
#'
#' @description
#' The leafwax package provides tools for probabilistic inversion of leaf wax
#' hydrogen isotope measurements (δ2H) to reconstruct precipitation isotope values.
#' It implements hierarchical Bayesian models that account for multiple sources of
#' uncertainty including measurement error, biological fractionation, and spatial
#' correlation in isotope patterns.
#'
#' @section Main Functions:
#' \describe{
#'   \item{\code{\link{invert_d2h}}}{Perform Bayesian inversion of leaf wax δ2H to precipitation δ2H}
#'   \item{\code{\link{available_models}}}{List all available calibration models}
#'   \item{\code{\link{load_posteriors}}}{Load posterior distributions for a specific model}
#'   \item{\code{\link{get_model_parameters}}}{Get model capabilities and required parameters}
#'   \item{\code{\link{validate_model_inputs}}}{Validate inputs for a specific model}
#'   \item{\code{\link{get_model_recommendations}}}{Get model recommendations based on available data}
#' }
#'
#' @section Available Models:
#' The package includes 14 calibration models with different capabilities:
#' \itemize{
#'   \item \strong{Basic models}: baseline, baseline_sp
#'   \item \strong{Elevation models}: baseline_env, baseline_env_sp, elevation_only_sp
#'   \item \strong{Vegetation models}: baseline_veg, baseline_veg_sp, c4_only_sp
#'   \item \strong{Combined models}: elevation_c4_sp, elevation_c4_interact_sp
#'   \item \strong{Full models}: full, full_sp, full_interact, full_interact_sp
#' }
#'
#' Models with "_sp" suffix use spatial Gaussian processes with 125 knots on a
#' Fibonacci sphere lattice for improved uncertainty quantification.
#'
#' @section Model Selection:
#' Choose models based on available ancillary data:
#' \itemize{
#'   \item Use \code{baseline} for simple applications with only location data
#'   \item Use \code{baseline_env} when elevation data is available
#'   \item Use \code{baseline_veg} when vegetation (PFT) data is available
#'   \item Use spatial models (_sp) for better uncertainty quantification
#'   \item Use \code{get_model_recommendations()} for automated model selection
#' }
#'
#' @section Key Features:
#' \itemize{
#'   \item Hierarchical Bayesian framework for uncertainty propagation
#'   \item Support for single and multi-location inversions
#'   \item Spatial correlation via Gaussian processes
#'   \item Automatic handling of missing covariates
#'   \item Comprehensive model validation and recommendations
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
#' @examples
#' # List available models
#' models <- available_models()
#' print(models)
#'
#' # Simple single-location inversion
#' result <- invert_d2h(
#'   d2h_wax = -150,
#'   longitude = -120,
#'   latitude = 40,
#'   model = "baseline"
#' )
#'
#' # Get model recommendations based on available data
#' recommendations <- get_model_recommendations(
#'   has_elevation = TRUE,
#'   prefer_spatial = TRUE
#' )
#'
#' @keywords internal
#' @importFrom jsonlite fromJSON
#' @importFrom stats rnorm quantile sd median runif cor aggregate
#' @importFrom utils read.csv write.csv data setTxtProgressBar txtProgressBar
"_PACKAGE"