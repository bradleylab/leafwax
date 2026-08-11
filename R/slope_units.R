# Internal conversions between fitted-model and physical slope units.

.validate_slope_scaling <- function(scaling) {
  required <- c("d2H_sd", "oipc_sd")
  if (is.null(scaling) || !all(required %in% names(scaling)) ||
      any(!is.finite(unlist(scaling[required]))) ||
      any(unlist(scaling[required]) <= 0)) {
    stop("scaling must contain positive finite d2H_sd and oipc_sd values.",
         call. = FALSE)
  }
  invisible(scaling)
}

.model_slope_to_physical <- function(slope, scaling) {
  .validate_slope_scaling(scaling)
  slope * scaling$d2H_sd / scaling$oipc_sd
}

.physical_slope_to_model <- function(slope, scaling) {
  .validate_slope_scaling(scaling)
  slope * scaling$oipc_sd / scaling$d2H_sd
}
