# Numerical Bayesian inversion for a linear calibration represented by paired
# posterior draws. The calculation integrates over calibration uncertainty
# without dividing by a sampled slope.

.trapezoid_weights <- function(grid) {
  spacing <- diff(grid)
  c(spacing[[1L]] / 2, (spacing[-1L] + spacing[-length(spacing)]) / 2,
    spacing[[length(spacing)]] / 2)
}

.log_sum_exp <- function(x) {
  maximum <- max(x)
  if (!is.finite(maximum)) {
    return(maximum)
  }
  maximum + log(sum(exp(x - maximum)))
}

.row_log_mean_exp <- function(x) {
  maxima <- apply(x, 1L, max)
  maxima + log(rowMeans(exp(sweep(x, 1L, maxima, FUN = "-"))))
}

.inverse_grid_once <- function(grid, y, intercept, slope, total_sd, prior) {
  quadrature_weights <- .trapezoid_weights(grid)
  means <- outer(grid, slope, FUN = "*")
  means <- sweep(means, 2L, intercept, FUN = "+")
  residuals <- sweep(means, 1L, rep(y, length(grid)), FUN = "-")
  log_likelihood <- sweep(
    -0.5 * residuals^2,
    2L,
    total_sd^2,
    FUN = "/"
  )
  log_likelihood <- sweep(
    log_likelihood,
    2L,
    log(total_sd) + 0.5 * log(2 * pi),
    FUN = "-"
  )

  log_prior <- .prior_log_density(grid, prior)
  log_marginal_likelihood <- .row_log_mean_exp(log_likelihood)
  log_unnormalized <- log_prior + log_marginal_likelihood
  log_normalizer <- .log_sum_exp(log_unnormalized + log(quadrature_weights))
  density <- exp(log_unnormalized - log_normalizer)

  log_component_evidence <- apply(
    sweep(log_likelihood, 1L, log_prior + log(quadrature_weights), FUN = "+"),
    2L,
    .log_sum_exp
  )
  log_component_weights <- log_component_evidence -
    .log_sum_exp(log_component_evidence)
  component_weights <- exp(log_component_weights)

  cumulative <- c(
    0,
    cumsum((density[-length(density)] + density[-1L]) * diff(grid) / 2)
  )
  cumulative <- cumulative / cumulative[[length(cumulative)]]

  list(
    grid = grid,
    density = density,
    quadrature_weights = quadrature_weights,
    cumulative = cumulative,
    log_prior = log_prior,
    log_likelihood = log_likelihood,
    log_component_evidence = log_component_evidence,
    component_weights = component_weights
  )
}

.inverse_grid_summary <- function(result, credible_level) {
  alpha <- (1 - credible_level) / 2
  quantiles <- stats::approx(
    x = result$cumulative,
    y = result$grid,
    xout = c(alpha, 0.5, 1 - alpha),
    ties = "ordered",
    rule = 2
  )$y
  mean <- sum(
    result$grid * result$density * result$quadrature_weights
  )
  variance <- sum(
    (result$grid - mean)^2 * result$density * result$quadrature_weights
  )
  list(
    mean = mean,
    median = quantiles[[2L]],
    sd = sqrt(max(variance, 0)),
    lower = quantiles[[1L]],
    upper = quantiles[[3L]],
    credible_level = credible_level
  )
}

.summary_difference <- function(first, second) {
  max(abs(
    unlist(first[c("mean", "median", "sd", "lower", "upper")]) -
      unlist(second[c("mean", "median", "sd", "lower", "upper")])
  ))
}

.sample_inverse_grid <- function(result, n_samples, seed) {
  if (is.null(seed) || !is.numeric(seed) || length(seed) != 1L ||
      !is.finite(seed) || seed != as.integer(seed)) {
    stop("seed must be an explicit finite integer when n_samples is positive.",
         call. = FALSE)
  }

  had_seed <- exists(".Random.seed", envir = .GlobalEnv, inherits = FALSE)
  if (had_seed) {
    old_seed <- get(".Random.seed", envir = .GlobalEnv, inherits = FALSE)
  }
  on.exit({
    if (had_seed) {
      assign(".Random.seed", old_seed, envir = .GlobalEnv)
    } else if (exists(".Random.seed", envir = .GlobalEnv, inherits = FALSE)) {
      rm(".Random.seed", envir = .GlobalEnv)
    }
  }, add = TRUE)

  set.seed(as.integer(seed))
  probabilities <- stats::runif(n_samples)
  stats::approx(
    x = result$cumulative,
    y = result$grid,
    xout = probabilities,
    ties = "ordered",
    rule = 2
  )$y
}

.validate_inverse_inputs <- function(y, intercept, slope, residual_sd,
                                     analytical_sd, prior) {
  if (!inherits(prior, "leafwax_d2h_prior")) {
    stop("prior must be a leafwax_d2h_prior object.", call. = FALSE)
  }
  if (!is.numeric(y) || length(y) != 1L || !is.finite(y)) {
    stop("y must be a finite numeric scalar.", call. = FALSE)
  }
  lengths <- c(length(intercept), length(slope), length(residual_sd))
  if (length(unique(lengths)) != 1L || lengths[[1L]] < 1L) {
    stop("intercept, slope, and residual_sd must have the same length.",
         call. = FALSE)
  }
  if (length(analytical_sd) == 1L) {
    analytical_sd <- rep(analytical_sd, lengths[[1L]])
  }
  if (length(analytical_sd) != lengths[[1L]]) {
    stop("analytical_sd must have length one or the same length as intercept.",
         call. = FALSE)
  }
  values <- c(intercept, slope, residual_sd, analytical_sd)
  if (!is.numeric(values) || any(!is.finite(values))) {
    stop("All likelihood inputs must be finite numeric values.", call. = FALSE)
  }
  if (any(residual_sd <= 0)) {
    stop("residual_sd must be positive.", call. = FALSE)
  }
  if (any(analytical_sd < 0)) {
    stop("analytical_sd must be non-negative.", call. = FALSE)
  }
  list(
    y = as.numeric(y),
    intercept = as.numeric(intercept),
    slope = as.numeric(slope),
    residual_sd = as.numeric(residual_sd),
    analytical_sd = as.numeric(analytical_sd),
    prior = prior
  )
}

.initial_inverse_domain <- function(y, intercept, slope, total_sd, prior,
                                    tail_mass_tolerance) {
  if (all(is.finite(prior$support))) {
    return(prior$support)
  }
  tail_probability <- max(min(tail_mass_tolerance / 2, 1e-6), 1e-12)
  domain <- .prior_quantile(c(tail_probability, 1 - tail_probability), prior)
  prior_mean <- prior$parameters$mean
  prior_variance <- prior$parameters$sd^2
  likelihood_precision <- slope^2 / total_sd^2
  posterior_variance <- 1 / (1 / prior_variance + likelihood_precision)
  posterior_mean <- posterior_variance * (
    prior_mean / prior_variance + slope * (y - intercept) / total_sd^2
  )
  posterior_sd <- sqrt(posterior_variance)
  candidates <- c(
    stats::qnorm(tail_probability, posterior_mean, posterior_sd),
    stats::qnorm(1 - tail_probability, posterior_mean, posterior_sd)
  )
  candidates <- candidates[is.finite(candidates)]
  if (length(candidates)) {
    domain <- range(c(domain, candidates))
  }
  domain
}

#' Bayesian inversion of a linear calibration posterior
#'
#' Integrates a proper prior with a normal likelihood for paired posterior
#' draws of the intercept, slope, and residual standard deviation. This avoids
#' unstable division by slopes near zero and preserves calibration-draw pairing.
#'
#' @param y Observed response value.
#' @param intercept,slope,residual_sd Paired calibration posterior draws.
#' @param analytical_sd Known response-space analytical standard deviation.
#' @param prior A proper prior created by one of the `d2h_prior_*()` functions.
#' @param credible_level Probability in the central credible interval.
#' @param grid_size Odd number of grid points used for numerical integration.
#' @param integration_tolerance Maximum permitted change in reported summaries
#'   between nested numerical grids, in precipitation-isotope units.
#' @param tail_mass_tolerance Maximum permitted posterior mass in either outer
#'   grid cell for an unbounded prior.
#' @param max_refinements Maximum domain-expansion attempts.
#' @param n_samples Number of optional posterior samples to return.
#' @param seed Required integer seed when `n_samples` is positive.
#' @return A `leafwax_inverse_grid` object containing the normalized posterior,
#'   summaries, numerical and identifiability diagnostics, and optional samples.
#' @export
bayesian_linear_inverse <- function(
    y,
    intercept,
    slope,
    residual_sd,
    analytical_sd = 0,
    prior,
    credible_level = 0.9,
    grid_size = 2001L,
    integration_tolerance = 1e-3,
    tail_mass_tolerance = 1e-8,
    max_refinements = 4L,
    n_samples = 0L,
    seed = NULL) {
  inputs <- .validate_inverse_inputs(
    y, intercept, slope, residual_sd, analytical_sd, prior
  )
  y <- inputs$y
  intercept <- inputs$intercept
  slope <- inputs$slope
  residual_sd <- inputs$residual_sd
  analytical_sd <- inputs$analytical_sd
  prior <- inputs$prior

  if (!is.numeric(credible_level) || length(credible_level) != 1L ||
      !is.finite(credible_level) || credible_level <= 0 || credible_level >= 1) {
    stop("credible_level must be between zero and one.", call. = FALSE)
  }
  grid_size <- as.integer(grid_size)
  if (!is.finite(grid_size) || grid_size < 501L) {
    stop("grid_size must be at least 501.", call. = FALSE)
  }
  if (grid_size %% 2L == 0L) {
    grid_size <- grid_size + 1L
  }
  if (!is.numeric(integration_tolerance) || integration_tolerance <= 0 ||
      !is.finite(integration_tolerance)) {
    stop("integration_tolerance must be positive and finite.", call. = FALSE)
  }
  if (!is.numeric(tail_mass_tolerance) || tail_mass_tolerance <= 0 ||
      !is.finite(tail_mass_tolerance)) {
    stop("tail_mass_tolerance must be positive and finite.", call. = FALSE)
  }
  max_refinements <- as.integer(max_refinements)
  n_samples <- as.integer(n_samples)
  if (!is.finite(max_refinements) || max_refinements < 0L ||
      !is.finite(n_samples) || n_samples < 0L) {
    stop("max_refinements and n_samples must be non-negative integers.",
         call. = FALSE)
  }
  if (n_samples > 0L && is.null(seed)) {
    stop("An explicit seed is required when n_samples is positive.",
         call. = FALSE)
  }

  total_sd <- sqrt(residual_sd^2 + analytical_sd^2)
  domain <- .initial_inverse_domain(
    y, intercept, slope, total_sd, prior, tail_mass_tolerance
  )
  bounded <- all(is.finite(prior$support))
  tail_ok <- bounded
  expansion_count <- 0L

  repeat {
    grid <- seq(domain[[1L]], domain[[2L]], length.out = grid_size)
    result <- .inverse_grid_once(
      grid, y, intercept, slope, total_sd, prior
    )
    edge_mass <- result$density[c(1L, length(result$density))] *
      diff(grid)[[1L]] / 2
    tail_ok <- bounded || all(edge_mass <= tail_mass_tolerance)
    if (tail_ok || expansion_count >= max_refinements) {
      break
    }
    midpoint <- mean(domain)
    half_width <- diff(domain) * 1.75 / 2
    domain <- midpoint + c(-half_width, half_width)
    expansion_count <- expansion_count + 1L
  }

  fine_grid <- seq(domain[[1L]], domain[[2L]], length.out = 2L * grid_size - 1L)
  fine_result <- .inverse_grid_once(
    fine_grid, y, intercept, slope, total_sd, prior
  )
  coarse_summary <- .inverse_grid_summary(result, credible_level)
  fine_summary <- .inverse_grid_summary(fine_result, credible_level)
  integration_difference <- .summary_difference(coarse_summary, fine_summary)
  integration_ok <- integration_difference <= integration_tolerance

  finite_prior <- is.finite(fine_result$log_prior)
  kl_terms <- rep(0, length(fine_grid))
  positive_density <- fine_result$density > 0 & finite_prior
  kl_terms[positive_density] <- fine_result$density[positive_density] *
    (log(fine_result$density[positive_density]) -
       fine_result$log_prior[positive_density])
  kl_divergence <- sum(kl_terms * fine_result$quadrature_weights)
  component_weights <- fine_result$component_weights
  mixture_ess <- 1 / sum(component_weights^2)

  status <- if (tail_ok && integration_ok) "ok" else "inconclusive"
  posterior_samples <- NULL
  if (n_samples > 0L) {
    posterior_samples <- .sample_inverse_grid(
      fine_result, n_samples, seed
    )
  }

  structure(
    list(
      status = status,
      grid = fine_result$grid,
      density = fine_result$density,
      quadrature_weights = fine_result$quadrature_weights,
      summary = fine_summary,
      diagnostics = list(
        kl_posterior_prior_nats = kl_divergence,
        mixture_weight_ess = mixture_ess,
        slope_probability_positive = sum(component_weights[slope > 0]),
        slope_probability_negative = sum(component_weights[slope < 0]),
        slope_probability_zero = sum(component_weights[slope == 0]),
        integration_difference = integration_difference,
        integration_tolerance = integration_tolerance,
        tail_mass = edge_mass,
        tail_mass_tolerance = tail_mass_tolerance,
        domain_expansions = expansion_count,
        calibration_draws = length(slope)
      ),
      prior = prior,
      posterior_samples = posterior_samples,
      metadata = list(
        likelihood = "normal_linear_calibration_mixture",
        response_value = y,
        analytical_sd = unique(analytical_sd),
        seed = if (n_samples > 0L) as.integer(seed) else NULL
      )
    ),
    class = "leafwax_inverse_grid"
  )
}

.normalise_log_weights <- function(log_weights) {
  exp(log_weights - .log_sum_exp(log_weights))
}

.component_conditional_density <- function(result) {
  log_numerator <- sweep(
    result$log_likelihood,
    1L,
    result$log_prior,
    FUN = "+"
  )
  exp(sweep(
    log_numerator,
    2L,
    result$log_component_evidence,
    FUN = "-"
  ))
}

.weighted_inverse_result <- function(result, component_weights,
                                     credible_level) {
  conditional <- .component_conditional_density(result)
  density <- as.numeric(conditional %*% component_weights)
  density <- density / sum(density * result$quadrature_weights)
  cumulative <- c(
    0,
    cumsum((density[-length(density)] + density[-1L]) *
             diff(result$grid) / 2)
  )
  cumulative <- cumulative / cumulative[[length(cumulative)]]
  weighted <- result
  weighted$density <- density
  weighted$cumulative <- cumulative
  weighted$component_weights <- component_weights
  weighted$summary <- .inverse_grid_summary(weighted, credible_level)
  weighted
}

.with_inverse_seed <- function(seed, code) {
  if (is.null(seed) || !is.numeric(seed) || length(seed) != 1L ||
      !is.finite(seed) || seed != as.integer(seed)) {
    stop("seed must be an explicit finite integer.", call. = FALSE)
  }
  had_seed <- exists(".Random.seed", envir = .GlobalEnv, inherits = FALSE)
  if (had_seed) {
    old_seed <- get(".Random.seed", envir = .GlobalEnv, inherits = FALSE)
  }
  on.exit({
    if (had_seed) {
      assign(".Random.seed", old_seed, envir = .GlobalEnv)
    } else if (exists(".Random.seed", envir = .GlobalEnv, inherits = FALSE)) {
      rm(".Random.seed", envir = .GlobalEnv)
    }
  }, add = TRUE)
  set.seed(as.integer(seed))
  force(code)
}

.sample_record_conditionals <- function(results, component_weights,
                                        n_samples, seed) {
  .with_inverse_seed(seed, {
    component <- sample.int(
      length(component_weights),
      size = n_samples,
      replace = TRUE,
      prob = component_weights
    )
    samples <- matrix(NA_real_, nrow = n_samples, ncol = length(results))
    for (observation in seq_along(results)) {
      conditional <- .component_conditional_density(results[[observation]])
      grid <- results[[observation]]$grid
      weights <- results[[observation]]$quadrature_weights
      for (draw_index in unique(component)) {
        selected <- which(component == draw_index)
        density <- conditional[, draw_index]
        cumulative <- c(
          0,
          cumsum((density[-length(density)] + density[-1L]) *
                   diff(grid) / 2)
        )
        cumulative <- cumulative / cumulative[[length(cumulative)]]
        samples[selected, observation] <- stats::approx(
          x = cumulative,
          y = grid,
          xout = stats::runif(length(selected)),
          ties = "ordered",
          rule = 2
        )$y
      }
    }
    list(samples = samples, component = component)
  })
}

#' Joint Bayesian inversion of a multi-sample record
#'
#' Each row has its own latent precipitation-isotope value and proper prior,
#' while all rows share and jointly reweight the paired calibration draws.
#'
#' @param y Numeric vector of observed response values.
#' @param intercept,slope Matrices with calibration draws in rows and
#'   observations in columns.
#' @param residual_sd Positive vector with one value per calibration draw.
#' @param analytical_sd Non-negative scalar or one value per observation.
#' @param prior A `leafwax_d2h_prior`, applied to every observation, or a list
#'   containing one such prior per observation.
#' @inheritParams bayesian_linear_inverse
#' @param n_samples Number of joint posterior samples. Set to zero for a
#'   deterministic summary without samples.
#' @return A `leafwax_inverse` object with row summaries, diagnostics, marginal
#'   grids, joint samples, and sampled calibration-draw identifiers.
#' @export
bayesian_record_inverse <- function(
    y,
    intercept,
    slope,
    residual_sd,
    analytical_sd = 0,
    prior,
    credible_level = 0.9,
    grid_size = 2001L,
    integration_tolerance = 1e-3,
    tail_mass_tolerance = 1e-8,
    max_refinements = 4L,
    n_samples,
    seed) {
  if (!is.numeric(y) || !length(y) || any(!is.finite(y))) {
    stop("y must be a non-empty finite numeric vector.", call. = FALSE)
  }
  intercept <- as.matrix(intercept)
  slope <- as.matrix(slope)
  if (!is.numeric(intercept) || !is.numeric(slope) ||
      !identical(dim(intercept), dim(slope)) || ncol(intercept) != length(y)) {
    stop("intercept and slope must be numeric matrices with one column per y.",
         call. = FALSE)
  }
  if (length(residual_sd) != nrow(intercept) ||
      any(!is.finite(residual_sd)) || any(residual_sd <= 0)) {
    stop("residual_sd must be positive with one value per calibration draw.",
         call. = FALSE)
  }
  if (length(analytical_sd) == 1L) {
    analytical_sd <- rep(analytical_sd, length(y))
  }
  if (length(analytical_sd) != length(y) ||
      any(!is.finite(analytical_sd)) || any(analytical_sd < 0)) {
    stop("analytical_sd must be non-negative with length one or length(y).",
         call. = FALSE)
  }
  if (inherits(prior, "leafwax_d2h_prior")) {
    priors <- rep(list(prior), length(y))
  } else if (is.list(prior) && length(prior) == length(y) &&
             all(vapply(prior, inherits, logical(1), "leafwax_d2h_prior"))) {
    priors <- prior
  } else {
    stop("prior must be a leafwax_d2h_prior or one such prior per observation.",
         call. = FALSE)
  }
  n_samples <- as.integer(n_samples)
  if (!is.finite(n_samples) || n_samples < 0L) {
    stop("n_samples must be a non-negative integer for record inversion.",
         call. = FALSE)
  }
  if (n_samples > 0L && missing(seed)) {
    stop("An explicit seed is required when n_samples is positive.",
         call. = FALSE)
  }

  marginal_results <- vector("list", length(y))
  coarse_summaries <- vector("list", length(y))
  fine_summaries <- vector("list", length(y))
  tail_ok <- logical(length(y))
  integration_ok <- logical(length(y))

  for (observation in seq_along(y)) {
    total_sd <- sqrt(residual_sd^2 + analytical_sd[[observation]]^2)
    domain <- .initial_inverse_domain(
      y[[observation]], intercept[, observation], slope[, observation],
      total_sd, priors[[observation]], tail_mass_tolerance
    )
    bounded <- all(is.finite(priors[[observation]]$support))
    expansion_count <- 0L
    repeat {
      coarse_grid <- seq(domain[[1L]], domain[[2L]], length.out = grid_size)
      coarse <- .inverse_grid_once(
        coarse_grid, y[[observation]], intercept[, observation],
        slope[, observation], total_sd, priors[[observation]]
      )
      edge_mass <- coarse$density[c(1L, length(coarse$density))] *
        diff(coarse_grid)[[1L]] / 2
      tail_ok[[observation]] <- bounded ||
        all(edge_mass <= tail_mass_tolerance)
      if (tail_ok[[observation]] || expansion_count >= max_refinements) {
        break
      }
      midpoint <- mean(domain)
      half_width <- diff(domain) * 1.75 / 2
      domain <- midpoint + c(-half_width, half_width)
      expansion_count <- expansion_count + 1L
    }
    fine_grid <- seq(
      domain[[1L]], domain[[2L]], length.out = 2L * grid_size - 1L
    )
    fine <- .inverse_grid_once(
      fine_grid, y[[observation]], intercept[, observation],
      slope[, observation], total_sd, priors[[observation]]
    )
    coarse_summaries[[observation]] <-
      .inverse_grid_summary(coarse, credible_level)
    fine_summaries[[observation]] <-
      .inverse_grid_summary(fine, credible_level)
    integration_ok[[observation]] <- .summary_difference(
      coarse_summaries[[observation]], fine_summaries[[observation]]
    ) <= integration_tolerance
    fine$log_likelihood <- NULL
    marginal_results[[observation]] <- fine
  }

  log_joint_weights <- Reduce(
    `+`, lapply(marginal_results, `[[`, "log_component_evidence")
  )
  joint_weights <- .normalise_log_weights(log_joint_weights)
  finish_results <- function(component_ids = NULL) {
    weighted_results <- vector("list", length(y))
    diagnostics <- vector("list", length(y))
    posterior_samples <- if (is.null(component_ids)) NULL else
      matrix(NA_real_, nrow = length(component_ids), ncol = length(y))

    for (observation in seq_along(y)) {
      total_sd <- sqrt(residual_sd^2 + analytical_sd[[observation]]^2)
      result <- .inverse_grid_once(
        marginal_results[[observation]]$grid,
        y[[observation]],
        intercept[, observation],
        slope[, observation],
        total_sd,
        priors[[observation]]
      )
      weighted <- .weighted_inverse_result(
        result, joint_weights, credible_level
      )

      if (!is.null(component_ids)) {
        conditional <- .component_conditional_density(result)
        for (draw_index in unique(component_ids)) {
          selected <- which(component_ids == draw_index)
          density <- conditional[, draw_index]
          cumulative <- c(
            0,
            cumsum((density[-length(density)] + density[-1L]) *
                     diff(result$grid) / 2)
          )
          cumulative <- cumulative / cumulative[[length(cumulative)]]
          posterior_samples[selected, observation] <- stats::approx(
            x = cumulative,
            y = result$grid,
            xout = stats::runif(length(selected)),
            ties = "ordered",
            rule = 2
          )$y
        }
      }

      finite_prior <- is.finite(weighted$log_prior)
      use <- weighted$density > 0 & finite_prior
      kl_terms <- rep(0, length(weighted$grid))
      kl_terms[use] <- weighted$density[use] *
        (log(weighted$density[use]) - weighted$log_prior[use])
      diagnostics[[observation]] <- list(
        kl_posterior_prior_nats = sum(
          kl_terms * weighted$quadrature_weights
        ),
        slope_probability_positive = sum(
          joint_weights[slope[, observation] > 0]
        ),
        slope_probability_negative = sum(
          joint_weights[slope[, observation] < 0]
        ),
        slope_probability_zero = sum(
          joint_weights[slope[, observation] == 0]
        ),
        integration_difference = .summary_difference(
          coarse_summaries[[observation]], fine_summaries[[observation]]
        ),
        tail_ok = tail_ok[[observation]]
      )
      weighted$log_likelihood <- NULL
      weighted_results[[observation]] <- weighted
    }
    list(
      weighted_results = weighted_results,
      diagnostics = diagnostics,
      posterior_samples = posterior_samples,
      component_ids = component_ids
    )
  }

  finished <- if (n_samples > 0L) {
    .with_inverse_seed(seed, {
      component_ids <- sample.int(
        length(joint_weights), n_samples, replace = TRUE,
        prob = joint_weights
      )
      finish_results(component_ids)
    })
  } else {
    finish_results()
  }
  weighted_results <- finished$weighted_results
  summary <- do.call(rbind, lapply(weighted_results, function(result) {
    as.data.frame(result$summary, stringsAsFactors = FALSE)
  }))
  rownames(summary) <- NULL

  status <- if (all(tail_ok) && all(integration_ok)) "ok" else "inconclusive"
  structure(
    list(
      status = status,
      summary = summary,
      posterior_draws = finished$posterior_samples,
      calibration_draw_ids = finished$component_ids,
      grids = lapply(weighted_results, `[[`, "grid"),
      densities = lapply(weighted_results, `[[`, "density"),
      quadrature_weights = lapply(
        weighted_results, `[[`, "quadrature_weights"
      ),
      diagnostics = list(
        observations = finished$diagnostics,
        mixture_weight_ess = 1 / sum(joint_weights^2),
        calibration_draws = nrow(intercept),
        integration_tolerance = integration_tolerance,
        tail_mass_tolerance = tail_mass_tolerance
      ),
      prior = priors,
      metadata = list(
        likelihood = "joint_normal_linear_calibration_mixture",
        credible_level = credible_level,
        seed = if (n_samples > 0L) as.integer(seed) else NULL,
        n_samples = n_samples
      )
    ),
    class = "leafwax_inverse"
  )
}
