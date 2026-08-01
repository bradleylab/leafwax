# Proper priors for Bayesian precipitation-isotope inversion.

.validate_prior_scalar <- function(value, name) {
  if (!is.numeric(value) || length(value) != 1L || !is.finite(value)) {
    stop(name, " must be a finite numeric scalar.", call. = FALSE)
  }
  as.numeric(value)
}

.new_d2h_prior <- function(family, parameters, support, units) {
  structure(
    list(
      family = family,
      parameters = parameters,
      support = support,
      units = units
    ),
    class = "leafwax_d2h_prior"
  )
}

#' Normal prior for precipitation-isotope inversion
#'
#' @param mean Prior mean in precipitation-isotope units.
#' @param sd Positive prior standard deviation.
#' @param units Label for the isotope units.
#' @return A proper prior specification for Bayesian inversion.
#' @export
d2h_prior_normal <- function(mean, sd, units = "permil VSMOW") {
  mean <- .validate_prior_scalar(mean, "mean")
  sd <- .validate_prior_scalar(sd, "sd")
  if (sd <= 0) {
    stop("sd must be positive.", call. = FALSE)
  }
  .new_d2h_prior("normal", list(mean = mean, sd = sd), c(-Inf, Inf), units)
}

#' Truncated-normal prior for precipitation-isotope inversion
#'
#' @param mean Mean of the untruncated normal distribution.
#' @param sd Positive standard deviation of the untruncated normal distribution.
#' @param lower,upper Finite prior bounds with `lower < upper`.
#' @param units Label for the isotope units.
#' @return A proper prior specification for Bayesian inversion.
#' @export
d2h_prior_truncated_normal <- function(mean, sd, lower, upper,
                                       units = "permil VSMOW") {
  mean <- .validate_prior_scalar(mean, "mean")
  sd <- .validate_prior_scalar(sd, "sd")
  lower <- .validate_prior_scalar(lower, "lower")
  upper <- .validate_prior_scalar(upper, "upper")
  if (sd <= 0) {
    stop("sd must be positive.", call. = FALSE)
  }
  if (lower >= upper) {
    stop("lower must be less than upper.", call. = FALSE)
  }
  normal_mass <- stats::pnorm(upper, mean, sd) - stats::pnorm(lower, mean, sd)
  if (!is.finite(normal_mass) || normal_mass <= 0) {
    stop("The truncated-normal prior has no numerically resolvable mass.",
         call. = FALSE)
  }
  .new_d2h_prior(
    "truncated_normal",
    list(mean = mean, sd = sd, normal_mass = normal_mass),
    c(lower, upper),
    units
  )
}

#' Uniform prior for precipitation-isotope inversion
#'
#' @param lower,upper Finite prior bounds with `lower < upper`.
#' @param units Label for the isotope units.
#' @return A proper prior specification for Bayesian inversion.
#' @export
d2h_prior_uniform <- function(lower, upper, units = "permil VSMOW") {
  lower <- .validate_prior_scalar(lower, "lower")
  upper <- .validate_prior_scalar(upper, "upper")
  if (lower >= upper) {
    stop("lower must be less than upper.", call. = FALSE)
  }
  .new_d2h_prior("uniform", list(), c(lower, upper), units)
}

.prior_log_density <- function(x, prior) {
  if (!inherits(prior, "leafwax_d2h_prior")) {
    stop("prior must be a leafwax_d2h_prior object.", call. = FALSE)
  }
  if (prior$family == "normal") {
    return(stats::dnorm(
      x, prior$parameters$mean, prior$parameters$sd, log = TRUE
    ))
  }
  inside <- x >= prior$support[[1L]] & x <= prior$support[[2L]]
  answer <- rep(-Inf, length(x))
  if (prior$family == "uniform") {
    answer[inside] <- -log(diff(prior$support))
    return(answer)
  }
  if (prior$family == "truncated_normal") {
    answer[inside] <- stats::dnorm(
      x[inside], prior$parameters$mean, prior$parameters$sd, log = TRUE
    ) - log(prior$parameters$normal_mass)
    return(answer)
  }
  stop("Unsupported precipitation-isotope prior family.", call. = FALSE)
}

.prior_quantile <- function(probability, prior) {
  if (prior$family == "normal") {
    return(stats::qnorm(
      probability, prior$parameters$mean, prior$parameters$sd
    ))
  }
  if (prior$family == "uniform") {
    return(prior$support[[1L]] + probability * diff(prior$support))
  }
  lower_probability <- stats::pnorm(
    prior$support[[1L]], prior$parameters$mean, prior$parameters$sd
  )
  stats::qnorm(
    lower_probability + probability * prior$parameters$normal_mass,
    prior$parameters$mean,
    prior$parameters$sd
  )
}

#' @export
print.leafwax_d2h_prior <- function(x, ...) {
  cat("Precipitation-isotope prior:", x$family, "\n")
  cat("Support:", paste(x$support, collapse = " to "), x$units, "\n")
  invisible(x)
}
