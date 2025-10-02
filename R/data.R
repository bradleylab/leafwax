# Data documentation for leafwax package

#' Example leaf wax hydrogen isotope data
#'
#' A dataset containing example leaf wax hydrogen isotope measurements
#' from various locations for testing the inversion functions.
#'
#' @format A data frame with 10 rows and 9 variables:
#' \describe{
#'   \item{site_name}{Character, site identification name}
#'   \item{longitude}{Numeric, longitude in decimal degrees (-180 to 180)}
#'   \item{latitude}{Numeric, latitude in decimal degrees (-90 to 90)}
#'   \item{elevation}{Numeric, elevation in meters above sea level}
#'   \item{d2h_wax}{Numeric, leaf wax δ2H value in per mil (‰) VSMOW}
#'   \item{d2h_wax_err}{Numeric, analytical uncertainty in per mil (‰)}
#'   \item{c4_percent}{Numeric, percentage of C4 vegetation (0-100)}
#'   \item{pft_tree}{Numeric, fraction of tree plant functional type (0-1)}
#'   \item{pft_grass}{Numeric, fraction of grass plant functional type (0-1)}
#' }
#'
#' @source Synthetic data based on typical leaf wax isotope values from
#' published literature. Values are representative of North American sites.
#'
#' @examples
#' \dontrun{
#' data(example_leafwax_data)
#' head(example_leafwax_data)
#'
#' # Use for inversion
#' result <- invert_d2h(
#'   d2h_wax = example_leafwax_data$d2h_wax,
#'   longitude = example_leafwax_data$longitude,
#'   latitude = example_leafwax_data$latitude,
#'   model = "baseline"
#' )
#' }
"example_leafwax_data"

#' Model metadata for all calibration models
#'
#' A list containing metadata and parameter information for all 14 available
#' calibration models used in leaf wax hydrogen isotope inversion.
#'
#' @format A named list with 14 elements, one for each model. Each element contains:
#' \describe{
#'   \item{name}{Character, model identifier}
#'   \item{description}{Character, human-readable model description}
#'   \item{has_spatial}{Logical, whether model includes spatial Gaussian process}
#'   \item{has_elevation}{Logical, whether model includes elevation effects}
#'   \item{has_c4}{Logical, whether model includes C4 vegetation effects}
#'   \item{has_vegetation}{Logical, whether model includes PFT effects}
#'   \item{n_parameters}{Integer, number of model parameters}
#'   \item{n_knots}{Integer, number of spatial knots (125 for spatial models, 0 otherwise)}
#'   \item{required_inputs}{Character vector, required input variables}
#' }
#'
#' @source Model metadata generated from the hierarchical Bayesian calibration
#' models described in the package documentation.
#'
#' @examples
#' \dontrun{
#' data(model_metadata)
#' names(model_metadata)
#'
#' # View information for baseline_sp model
#' model_metadata$baseline_sp
#'
#' # Check which models include elevation
#' elevation_models <- sapply(model_metadata, function(x) x$has_elevation)
#' names(model_metadata)[elevation_models]
#' }
"model_metadata"

#' Spatial knot locations for Gaussian process models
#'
#' Coordinates of the 125 knot locations on a Fibonacci sphere lattice
#' used by all spatial (_sp) models for Gaussian process approximation.
#'
#' @format A data frame with 125 rows and 3 variables:
#' \describe{
#'   \item{knot_id}{Integer, knot identifier (1-125)}
#'   \item{longitude}{Numeric, longitude in decimal degrees}
#'   \item{latitude}{Numeric, latitude in decimal degrees}
#' }
#'
#' @details The knot locations are generated using a Fibonacci sphere
#' algorithm to ensure approximately uniform coverage of the globe.
#' All spatial models use the same knot locations for consistency.
#'
#' @source Generated using the \code{generate_fibonacci_sphere} function
#' with 125 points.
#'
#' @examples
#' \dontrun{
#' data(spatial_knots)
#'
#' # Visualize knot locations
#' plot(spatial_knots$longitude, spatial_knots$latitude,
#'      pch = 19, col = "blue",
#'      xlab = "Longitude", ylab = "Latitude",
#'      main = "125 Fibonacci Sphere Knots")
#' }
"spatial_knots"

#' OIPC global precipitation isotope data
#'
#' Global gridded precipitation hydrogen isotope values from the
#' Online Isotopes in Precipitation Calculator (OIPC).
#'
#' @format A data frame with columns:
#' \describe{
#'   \item{longitude}{Numeric, longitude in decimal degrees}
#'   \item{latitude}{Numeric, latitude in decimal degrees}
#'   \item{d2h_precip}{Numeric, mean annual precipitation δ2H in per mil (‰)}
#'   \item{d2h_precip_sd}{Numeric, standard deviation of δ2H values}
#' }
#'
#' @source Bowen, G. J. (2023). The Online Isotopes in Precipitation Calculator,
#' version 3.2. \url{http://www.waterisotopes.org}
#'
#' @references
#' Bowen, G. J., & Revenaugh, J. (2003). Interpolating the isotopic composition
#' of modern meteoric precipitation. Water Resources Research, 39(10), 1299.
#' \doi{10.1029/2003WR002086}
#'
#' @examples
#' \dontrun{
#' data(oipc_data)
#'
#' # Map global precipitation isotopes
#' library(ggplot2)
#' ggplot(oipc_data, aes(x = longitude, y = latitude, fill = d2h_precip)) +
#'   geom_tile() +
#'   scale_fill_gradient2(low = "blue", mid = "white", high = "red",
#'                       midpoint = -50) +
#'   labs(title = "Global Precipitation δ2H",
#'        fill = "δ2H (‰)")
#' }
"oipc_data"