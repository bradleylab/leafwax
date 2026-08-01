test_that("proper precipitation-isotope priors validate their parameters", {
  p_normal <- d2h_prior_normal(mean = -70, sd = 40)
  p_trunc <- d2h_prior_truncated_normal(
    mean = -70, sd = 40, lower = -250, upper = 50
  )
  p_uniform <- d2h_prior_uniform(lower = -250, upper = 50)

  expect_s3_class(p_normal, "leafwax_d2h_prior")
  expect_equal(p_normal$family, "normal")
  expect_equal(p_trunc$family, "truncated_normal")
  expect_equal(p_uniform$family, "uniform")
  expect_equal(p_uniform$support, c(-250, 50))

  expect_error(d2h_prior_normal(mean = 0, sd = 0), "positive")
  expect_error(
    d2h_prior_truncated_normal(0, 1, lower = 2, upper = 1),
    "lower"
  )
  expect_error(d2h_prior_uniform(lower = 1, upper = 1), "lower")
  expect_error(d2h_prior_normal(mean = NA_real_, sd = 1), "finite")
})

test_that("Bayesian linear inversion agrees with the conjugate normal result", {
  prior <- d2h_prior_normal(mean = -1, sd = 3)
  result <- bayesian_linear_inverse(
    y = 4,
    intercept = 0,
    slope = 2,
    residual_sd = 1,
    analytical_sd = 0,
    prior = prior
  )

  expected_var <- 1 / (1 / 3^2 + 2^2 / 1^2)
  expected_mean <- expected_var * (-1 / 3^2 + 2 * 4 / 1^2)

  expect_s3_class(result, "leafwax_inverse_grid")
  expect_equal(result$status, "ok")
  expect_equal(result$summary$mean, expected_mean, tolerance = 2e-3)
  expect_equal(result$summary$sd, sqrt(expected_var), tolerance = 2e-3)
  expect_equal(result$summary$median, expected_mean, tolerance = 2e-3)
  expect_equal(
    sum(result$density * result$quadrature_weights),
    1,
    tolerance = 1e-8
  )
})

test_that("bounded priors keep posterior mass inside declared support", {
  prior <- d2h_prior_uniform(lower = -20, upper = 10)
  result <- bayesian_linear_inverse(
    y = 0,
    intercept = c(-1, 1),
    slope = c(-0.5, 0.5),
    residual_sd = c(2, 2),
    prior = prior
  )

  expect_equal(range(result$grid), c(-20, 10))
  expect_gte(result$summary$lower, -20)
  expect_lte(result$summary$upper, 10)
  expect_true(is.finite(result$diagnostics$kl_posterior_prior_nats))
})

test_that("zero and sign-changing slopes yield a proper prior-sensitive posterior", {
  prior <- d2h_prior_normal(mean = -70, sd = 30)
  result <- bayesian_linear_inverse(
    y = -150,
    intercept = c(-150, -150, -150),
    slope = c(-0.01, 0, 0.01),
    residual_sd = rep(15, 3),
    prior = prior
  )

  expect_equal(result$status, "ok")
  expect_true(all(is.finite(result$density)))
  expect_equal(result$diagnostics$slope_probability_positive, 1 / 3,
               tolerance = 0.02)
  expect_lt(result$diagnostics$kl_posterior_prior_nats, 0.05)
  expect_gt(result$diagnostics$mixture_weight_ess, 2.9)
})

test_that("posterior samples require and honor an explicit seed", {
  args <- list(
    y = 1,
    intercept = c(0, 0.2),
    slope = c(0.8, 1.1),
    residual_sd = c(1, 1),
    prior = d2h_prior_normal(0, 2),
    n_samples = 20
  )

  expect_error(do.call(bayesian_linear_inverse, args), "seed")
  a <- do.call(bayesian_linear_inverse, c(args, list(seed = 20260801)))
  b <- do.call(bayesian_linear_inverse, c(args, list(seed = 20260801)))
  expect_equal(a$posterior_samples, b$posterior_samples)
  expect_length(a$posterior_samples, 20)
})

test_that("invalid likelihood and prior inputs fail before inference", {
  prior <- d2h_prior_normal(0, 1)
  expect_error(
    bayesian_linear_inverse(
      y = 0, intercept = 0, slope = 1, residual_sd = 0, prior = prior
    ),
    "residual_sd"
  )
  expect_error(
    bayesian_linear_inverse(
      y = 0, intercept = c(0, 1), slope = 1,
      residual_sd = c(1, 1), prior = prior
    ),
    "same length"
  )
  expect_error(
    bayesian_linear_inverse(
      y = 0, intercept = 0, slope = 1, residual_sd = 1, prior = NULL
    ),
    "leafwax_d2h_prior"
  )
})

test_that("record inversion jointly reweights paired calibration draws", {
  prior <- d2h_prior_normal(0, 4)
  result <- bayesian_record_inverse(
    y = c(1, 5),
    intercept = matrix(c(0, 0, 0, 0), nrow = 2),
    slope = matrix(c(1, 1, 1, 2), nrow = 2),
    residual_sd = c(0.5, 0.5),
    prior = prior,
    n_samples = 200,
    seed = 20260801
  )

  expect_s3_class(result, "leafwax_inverse")
  expect_equal(result$status, "ok")
  expect_equal(dim(result$posterior_draws), c(200, 2))
  expect_length(unique(result$calibration_draw_ids), 2)
  expect_gt(result$diagnostics$mixture_weight_ess, 1)
  expect_lt(result$diagnostics$mixture_weight_ess, 2)
})

test_that("record inversion samples are reproducible and retain row dependence", {
  args <- list(
    y = c(0, 0),
    intercept = matrix(c(-2, 2, -2, 2), nrow = 2),
    slope = matrix(1, nrow = 2, ncol = 2),
    residual_sd = c(0.2, 0.2),
    prior = d2h_prior_normal(0, 5),
    n_samples = 300,
    seed = 71
  )
  first <- do.call(bayesian_record_inverse, args)
  second <- do.call(bayesian_record_inverse, args)

  expect_equal(first$posterior_draws, second$posterior_draws)
  expect_gt(stats::cor(first$posterior_draws[, 1],
                       first$posterior_draws[, 2]), 0.9)
})

test_that("public inversion requires a prior and returns diagnostic object", {
  expect_error(
    invert_d2H(
      d2H_wax = -180, d2H_wax_sd = 3,
      longitude = -90, latitude = 38,
      model_name = "baseline", verbose = FALSE
    ),
    "prior is required"
  )
  skip_if_preview_posteriors("baseline")
  result <- invert_d2H(
    d2H_wax = -180, d2H_wax_sd = 3,
    longitude = -90, latitude = 38,
    model_name = "baseline", n_posterior_draws = 80,
    prior = d2h_prior_normal(-70, 30), verbose = FALSE
  )

  expect_s3_class(result, "leafwax_inverse")
  expect_named(result$summary, c(
    "longitude", "latitude", "elevation", "d2h_wax", "d2h_wax_err",
    "d2h_precip_mean", "d2h_precip_median", "d2h_precip_sd",
    "d2h_precip_lower", "d2h_precip_upper", "prediction_interval_width"
  ))
  expect_true(is.finite(result$diagnostics$mixture_weight_ess))
  expect_true(is.list(result$diagnostics$draw_bank_stability))
  expect_null(result$posterior_draws)
})

test_that("public Bayesian inversion retains zero and negative slope draws", {
  skip_if_preview_posteriors("baseline")
  prior <- d2h_prior_normal(-70, 30)
  zero <- invert_d2H(
    d2H_wax = -180, d2H_wax_sd = 3,
    longitude = -90, latitude = 38,
    model_name = "baseline", n_posterior_draws = 40,
    slope = 0, prior = prior, verbose = FALSE
  )
  negative <- invert_d2H(
    d2H_wax = -180, d2H_wax_sd = 3,
    longitude = -90, latitude = 38,
    model_name = "baseline", n_posterior_draws = 40,
    slope = -0.2, prior = prior, verbose = FALSE
  )

  expect_equal(zero$diagnostics$observations[[1]]$slope_probability_zero, 1)
  expect_equal(
    negative$diagnostics$observations[[1]]$slope_probability_negative, 1
  )
  expect_true(all(is.finite(negative$summary$d2h_precip_mean)))
})

test_that("public inversion refuses incomplete designs and implicit sampling", {
  prior <- d2h_prior_normal(-70, 30)
  expect_error(
    invert_d2H(
      d2H_wax = -180, d2H_wax_sd = 3,
      longitude = -90, latitude = 38,
      model_name = "full_sp", prior = prior, verbose = FALSE
    ),
    "currently supports only"
  )
  skip_if_preview_posteriors("baseline")
  expect_error(
    invert_d2H(
      d2H_wax = -180, d2H_wax_sd = 3,
      longitude = -90, latitude = 38,
      model_name = "baseline", prior = prior,
      return_full = TRUE, verbose = FALSE
    ),
    "n_inverse_samples"
  )
  expect_error(
    invert_d2H(
      d2H_wax = -180, d2H_wax_sd = 3,
      longitude = -90, latitude = 38,
      model_name = "baseline", prior = prior,
      return_full = TRUE, n_inverse_samples = 10, verbose = FALSE
    ),
    "explicit seed"
  )
})

test_that("multi-row public inversion requires one explicit same-site record", {
  prior <- d2h_prior_normal(-70, 30)
  expect_error(
    invert_d2H(
      d2H_wax = c(-180, -175), d2H_wax_sd = c(3, 3),
      longitude = c(-90, -90), latitude = c(38, 38),
      model_name = "baseline", prior = prior, verbose = FALSE
    ),
    "record_id is required"
  )
  expect_error(
    invert_d2H(
      d2H_wax = c(-180, -175), d2H_wax_sd = c(3, 3),
      longitude = c(-90, -89), latitude = c(38, 38),
      record_id = "record-a", model_name = "baseline",
      prior = prior, verbose = FALSE
    ),
    "must share longitude"
  )
})

test_that("preview fixtures fail closed at inferential boundaries", {
  expect_error(
    require_inference_tier("light", "baseline", "unit test", 100),
    "cannot be used by unit test"
  )
  expect_silent(require_inference_tier("heavy", "baseline", "unit test", 12000))

  fake <- list(
    posterior_draws = matrix(seq_len(200), nrow = 100, ncol = 2),
    model_info = list(model_name = "baseline", posterior_tier = "light")
  )
  expect_error(
    detect_change(
      fake, age = c(0, 1), baseline_interval = c(0, 0),
      sigma_residual = 15, beta_eff = 0.6
    ),
    "cannot be used by detect_change"
  )
})

test_that("development build does not route downloads to an older release", {
  expect_error(
    get_data_url("baseline", "latest"),
    "disabled in this development build"
  )
})

test_that("ensemble and comparison APIs have no implicit scientific defaults", {
  prior <- d2h_prior_normal(-70, 30)
  expect_error(
    invert_d2H_ensemble(
      d2H_wax = -180, d2H_wax_sd = 3,
      longitude = -90, latitude = 38,
      prior = prior, n_inverse_samples = 10, seed = 7
    ),
    "models must be supplied explicitly"
  )
  expect_error(
    invert_d2H_ensemble(
      d2H_wax = -180, d2H_wax_sd = 3,
      longitude = -90, latitude = 38,
      models = "full_sp", prior = prior,
      n_inverse_samples = 10, seed = 7
    ),
    "Unsupported Bayesian-inversion"
  )
  expect_error(
    compare_models(
      data.frame(d2h_wax = -180, longitude = -90, latitude = 38),
      models = c("baseline", "baseline_sp"), progress = FALSE
    ),
    "proper prior"
  )
})

test_that("explicit compatible ensemble, comparison, and record batch run", {
  skip_if_preview_posteriors("baseline")
  skip_if_preview_posteriors("baseline_sp")
  prior <- d2h_prior_normal(-70, 30)

  ensemble <- invert_d2H_ensemble(
    d2H_wax = -180, d2H_wax_sd = 3,
    longitude = -90, latitude = 38,
    models = c("baseline", "baseline_sp"),
    prior = prior, n_posterior_draws = 40,
    n_inverse_samples = 20, seed = 20260801,
    grid_size = 501, integration_tolerance = 0.02,
    draw_stability_tolerance = 5, verbose = FALSE
  )
  expect_s3_class(ensemble, "leafwax_inverse_ensemble")
  expect_equal(dim(ensemble$posterior_draws), c(40, 1))
  expect_setequal(ensemble$models_used, c("baseline", "baseline_sp"))

  record <- data.frame(
    d2h_wax = c(-180, -175), d2h_wax_err = c(3, 3),
    longitude = c(-90, -90), latitude = c(38, 38),
    record_id = c("record-a", "record-a")
  )
  batch <- batch_predict(
    record, model = "baseline", progress = FALSE,
    prior = prior, n_draws = 40, grid_size = 501,
    integration_tolerance = 0.02, draw_stability_tolerance = 5
  )
  expect_s3_class(batch, "leafwax_inverse")
  expect_equal(nrow(batch$summary), 2)

  comparison <- compare_models(
    record[1, ], models = c("baseline", "baseline_sp"),
    prior = prior, n_draws = 40, progress = FALSE,
    grid_size = 501, integration_tolerance = 0.02,
    draw_stability_tolerance = 5
  )
  expect_equal(nrow(comparison), 1)
  expect_equal(comparison$n_models, 2)
})
