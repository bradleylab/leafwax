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
