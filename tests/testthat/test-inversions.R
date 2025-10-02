test_that("invert_d2h performs basic inversions", {
  result <- invert_d2h(
    d2h_wax = -150,
    d2h_wax_sd = 3,
    longitude = -105,
    latitude = 40,
    model_name = "simple_oipc",
    n_iterations = 100
  )

  expect_type(result, "list")
  expect_true("summary" %in% names(result))
  expect_true("posterior_draws" %in% names(result))
  expect_true("model_info" %in% names(result))

  expect_s3_class(result$summary, "data.frame")
  expect_true(all(c("mean", "median", "sd", "ci_lower", "ci_upper") %in% names(result$summary)))

  expect_type(result$posterior_draws, "double")
  expect_equal(length(result$posterior_draws), 100)
})

test_that("predict_d2h_precip works with data frame input", {
  data <- create_test_data(3)

  result <- predict_d2h_precip(
    data = data,
    model = "minimal",
    n_iterations = 50,
    verbose = FALSE
  )

  expect_s3_class(result, "data.frame")
  expect_equal(nrow(result), 3)
  expect_true(all(c("d2h_precip_mean", "d2h_precip_median", "d2h_precip_sd",
                    "d2h_precip_ci_lower", "d2h_precip_ci_upper") %in% names(result)))
})

test_that("predict_d2h_precip works with vector inputs", {
  result <- predict_d2h_precip(
    d2h_wax = c(-150, -160, -140),
    longitude = c(-105, -110, -100),
    latitude = c(40, 35, 45),
    model = "minimal",
    n_iterations = 50,
    verbose = FALSE
  )

  expect_s3_class(result, "data.frame")
  expect_equal(nrow(result), 3)
  expect_true(all(c("d2h_precip_mean", "d2h_precip_median") %in% names(result)))
})

test_that("batch_predict processes multiple samples", {
  data <- create_test_data(10)

  result <- batch_predict(
    data,
    model_name = "minimal",
    n_iterations = 50,
    show_progress = FALSE
  )

  expect_s3_class(result, "data.frame")
  expect_equal(nrow(result), 10)
  expect_true(all(c("d2h_precip_mean", "d2h_precip_sd") %in% names(result)))

  expect_true(all(!is.na(result$d2h_precip_mean)))
  expect_true(all(result$d2h_precip_sd > 0))
})

test_that("invert_d2H_ensemble combines multiple models", {
  result <- invert_d2H_ensemble(
    d2h_wax = -150,
    d2h_wax_sd = 3,
    longitude = -105,
    latitude = 40,
    models = c("simple_oipc", "minimal"),
    ensemble_method = "equal",
    n_iterations = 50
  )

  expect_type(result, "list")
  expect_true("ensemble_summary" %in% names(result))
  expect_true("model_results" %in% names(result))
  expect_true("weights" %in% names(result))

  expect_equal(length(result$model_results), 2)
  expect_true(all(names(result$model_results) %in% c("simple_oipc", "minimal")))

  expect_type(result$weights, "double")
  expect_equal(sum(result$weights), 1)
})

test_that("validate_inputs catches errors", {
  expect_error(
    validate_inputs(d2h_wax = "not_a_number"),
    "must be numeric"
  )

  expect_error(
    validate_inputs(longitude = 200),
    "longitude"
  )

  expect_error(
    validate_inputs(latitude = -100),
    "latitude"
  )

  expect_error(
    validate_inputs(elevation = -500),
    "elevation"
  )

  expect_error(
    validate_inputs(c4_fraction = 150),
    "c4_fraction"
  )

  expect_error(
    validate_inputs(pft_tree = 0.3, pft_shrub = 0.4, pft_grass = 0.5),
    "PFT fractions"
  )

  expect_silent(
    validate_inputs(
      d2h_wax = -150,
      longitude = -105,
      latitude = 40,
      elevation = 1500,
      c4_fraction = 20,
      pft_tree = 0.4,
      pft_shrub = 0.3,
      pft_grass = 0.3
    )
  )
})

test_that("compare_models evaluates multiple models", {
  data <- create_test_data(5)

  result <- compare_models(
    data,
    models = c("simple_oipc", "minimal"),
    n_iterations = 50,
    verbose = FALSE
  )

  expect_s3_class(result, "data.frame")
  expect_true("model" %in% names(result))
  expect_true("rmse" %in% names(result))

  expect_equal(nrow(result), 2)
  expect_true(all(result$model %in% c("simple_oipc", "minimal")))
})

test_that("inversion handles missing covariates gracefully", {
  result <- invert_d2h(
    d2h_wax = -150,
    d2h_wax_sd = 3,
    longitude = -105,
    latitude = 40,
    model_name = "auto",
    n_iterations = 50
  )

  expect_type(result, "list")
  expect_match(result$model_info$model_name, "simple_oipc|minimal")
})

test_that("inversion propagates uncertainties correctly", {
  result_low_unc <- invert_d2h(
    d2h_wax = -150,
    d2h_wax_sd = 1,
    longitude = -105,
    latitude = 40,
    model_name = "minimal",
    n_iterations = 100
  )

  result_high_unc <- invert_d2h(
    d2h_wax = -150,
    d2h_wax_sd = 10,
    longitude = -105,
    latitude = 40,
    model_name = "minimal",
    n_iterations = 100
  )

  expect_lt(result_low_unc$summary$sd, result_high_unc$summary$sd)
  expect_lt(
    result_low_unc$summary$ci_upper - result_low_unc$summary$ci_lower,
    result_high_unc$summary$ci_upper - result_high_unc$summary$ci_lower
  )
})