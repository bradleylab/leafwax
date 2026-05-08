# Data documentation for the leafwax package.
# Documents only the .rda objects actually shipped under data/.

#' Example leaf wax hydrogen isotope data
#'
#' A 10-row data frame of synthetic leaf wax hydrogen isotope
#' measurements bundled for demonstration and testing.
#'
#' @format A data frame with 10 rows and 10 variables:
#' \describe{
#'   \item{site_id}{Character, site identifier}
#'   \item{longitude}{Numeric, longitude in decimal degrees (-180 to 180)}
#'   \item{latitude}{Numeric, latitude in decimal degrees (-90 to 90)}
#'   \item{elevation}{Numeric, elevation in meters above sea level}
#'   \item{d2h_wax}{Numeric, leaf wax hydrogen isotope value in per mil VSMOW}
#'   \item{d2h_wax_sd}{Numeric, analytical uncertainty in per mil}
#'   \item{c4_fraction}{Numeric, C4 vegetation fraction (0-1)}
#'   \item{pft_tree}{Numeric, tree plant functional type fraction (0-1)}
#'   \item{pft_shrub}{Numeric, shrub plant functional type fraction (0-1)}
#'   \item{pft_grass}{Numeric, grass plant functional type fraction (0-1)}
#' }
#'
#' @source Synthetic values designed to span the calibration range.
#' @examples
#' data(example_data)
#' head(example_data)
"example_data"

#' Model metadata for the v10 calibration models
#'
#' A list summarizing the 14 hierarchical Bayesian calibration models
#' shipped with the package. Field names match the v10 model variants
#' described in the manuscript.
#'
#' @format A named list. Each element is itself a list with fields
#'   describing one model: \code{name}, \code{description},
#'   \code{has_spatial}, \code{has_elevation}, \code{has_c4},
#'   \code{has_vegetation}, and \code{size_mb}. See
#'   \code{\link{get_all_model_metadata}} for the canonical accessor.
#'
#' @source Generated from the v10 hierarchical Bayesian calibration run.
#' @examples
#' data(model_metadata)
#' names(model_metadata)
"model_metadata"

#' Mini lookup table
#'
#' Compact precomputed lookup for fast non-Bayesian inversion smoke
#' tests. Used by examples in \code{\link{create_lookup_table}}.
#'
#' @format A data frame with one row per grid cell.
#' @keywords internal
"mini_lookup_table"

#' Mini posterior draws
#'
#' Compact subset of posterior draws used in tests and smoke checks.
#' Not for analytical use; see \code{\link{load_posteriors}} for the
#' full v10 posteriors shipped under \code{inst/extdata/posteriors/}.
#'
#' @format A list of draws indexed by model name.
#' @keywords internal
"mini_posteriors"
