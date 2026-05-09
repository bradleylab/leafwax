# Behavior of uncertainty_mode = c("absolute", "within_record") in
# invert_d2H. The two regimes are mutually exclusive (manuscript
# Section 4.5.3): sigma_within REPLACES the global posterior residual
# SD for within-record contrasts, it does not add on top of it.

test_that("invert_d2H absolute mode matches the manuscript single-site PI scale", {
  set.seed(7)
  res <- suppressWarnings(invert_d2H(
    d2H_wax = -130, d2H_wax_sd = 1,
    longitude = -90, latitude = 45,
    model_name = "baseline",
    uncertainty_mode = "absolute",
    verbose = FALSE
  ))
  # Manuscript Conclusions report posterior SD ~29 per mil (95% CI
  # 24-38) for single-point reconstructions; 90% CI width should be
  # in the 50-150 per mil band.
  expect_gt(res$prediction_interval_width, 50)
  expect_lt(res$prediction_interval_width, 150)
  expect_identical(attr(res, "leafwax_uncertainty_mode"), "absolute")
  expect_true(is.na(attr(res, "leafwax_sigma_within")))
})

test_that("invert_d2H within_record mode produces narrower PI than absolute when sigma_within is small", {
  set.seed(7)
  res_abs <- suppressWarnings(invert_d2H(
    d2H_wax = -130, d2H_wax_sd = 1,
    longitude = -90, latitude = 45,
    model_name = "baseline_sp",
    uncertainty_mode = "absolute",
    verbose = FALSE
  ))
  set.seed(7)
  res_wr <- suppressWarnings(invert_d2H(
    d2H_wax = -130, d2H_wax_sd = 1,
    longitude = -90, latitude = 45,
    model_name = "baseline_sp",
    uncertainty_mode = "within_record",
    sigma_within = 5,
    verbose = FALSE
  ))
  expect_lt(res_wr$prediction_interval_width, res_abs$prediction_interval_width)
  expect_identical(attr(res_wr, "leafwax_uncertainty_mode"), "within_record")
  expect_equal(attr(res_wr, "leafwax_sigma_within"), 5)
})

test_that("absolute + sigma_within is rejected (the regimes are mutually exclusive)", {
  expect_error(
    invert_d2H(d2H_wax = -130, d2H_wax_sd = 1,
               longitude = -90, latitude = 45,
               sigma_within = 5,
               uncertainty_mode = "absolute",
               verbose = FALSE),
    "sigma_within is meaningful only for uncertainty_mode = \"within_record\""
  )
})

test_that("within_record + sigma_within = NULL is rejected (manuscript Section 4.5.3 obligation 1)", {
  expect_error(
    invert_d2H(d2H_wax = -130, d2H_wax_sd = 1,
               longitude = -90, latitude = 45,
               uncertainty_mode = "within_record",
               verbose = FALSE),
    "uncertainty_mode = \"within_record\" requires a positive sigma_within"
  )
})

test_that("uncertainty_mode column makes the output self-describing", {
  res_a <- suppressWarnings(invert_d2H(
    d2H_wax = c(-180, -160), d2H_wax_sd = c(3, 3),
    longitude = c(-90, -85), latitude = c(38, 40),
    model_name = "baseline_sp",
    uncertainty_mode = "absolute",
    verbose = FALSE
  ))
  expect_true("uncertainty_mode" %in% names(res_a))
  expect_true(all(res_a$uncertainty_mode == "absolute"))

  res_w <- suppressWarnings(invert_d2H(
    d2H_wax = c(-180, -160), d2H_wax_sd = c(3, 3),
    longitude = c(-90, -85), latitude = c(38, 40),
    model_name = "baseline_sp",
    uncertainty_mode = "within_record",
    sigma_within = 5,
    verbose = FALSE
  ))
  expect_true(all(res_w$uncertainty_mode == "within_record"))
})

test_that("attrs propagate through return_full = TRUE", {
  res <- suppressWarnings(invert_d2H(
    d2H_wax = -180, d2H_wax_sd = 3,
    longitude = -90, latitude = 38,
    model_name = "baseline_sp",
    uncertainty_mode = "within_record",
    sigma_within = 7.5,
    return_full = TRUE,
    verbose = FALSE
  ))
  expect_identical(attr(res, "leafwax_uncertainty_mode"), "within_record")
  expect_equal(attr(res, "leafwax_sigma_within"), 7.5)
  expect_identical(res$model_info$uncertainty_mode, "within_record")
  expect_equal(res$model_info$sigma_within, 7.5)
})

test_that("detect_change rejects an absolute-mode reconstruction", {
  rec <- suppressWarnings(invert_d2H(
    d2H_wax = rep(-180, 10), d2H_wax_sd = rep(3, 10),
    longitude = rep(-90, 10), latitude = rep(38, 10),
    model_name = "baseline_sp",
    return_full = TRUE,
    uncertainty_mode = "absolute",
    verbose = FALSE
  ))
  expect_error(
    detect_change(
      reconstruction = rec,
      age = 1:10,
      baseline_interval = c(1, 3),
      test_intervals = c(7, 10),
      sigma_within = 5,
      beta_eff = 0.6
    ),
    "uncertainty_mode = \"within_record\""
  )
})

test_that("detect_change accepts a within_record reconstruction with matching sigma_within", {
  rec <- suppressWarnings(invert_d2H(
    d2H_wax = rep(-180, 10), d2H_wax_sd = rep(3, 10),
    longitude = rep(-90, 10), latitude = rep(38, 10),
    model_name = "baseline_sp",
    return_full = TRUE,
    uncertainty_mode = "within_record",
    sigma_within = 5,
    verbose = FALSE
  ))
  res <- detect_change(
    reconstruction = rec,
    age = 1:10,
    baseline_interval = c(1, 3),
    test_intervals = c(7, 10),
    sigma_within = 5,
    beta_eff = 0.6
  )
  expect_type(res, "list")
  expect_true("threshold" %in% names(res))
})

test_that("detect_change warns when the reconstruction sigma_within disagrees with the function arg", {
  rec <- suppressWarnings(invert_d2H(
    d2H_wax = rep(-180, 10), d2H_wax_sd = rep(3, 10),
    longitude = rep(-90, 10), latitude = rep(38, 10),
    model_name = "baseline_sp",
    return_full = TRUE,
    uncertainty_mode = "within_record",
    sigma_within = 5,
    verbose = FALSE
  ))
  expect_warning(
    detect_change(
      reconstruction = rec,
      age = 1:10,
      baseline_interval = c(1, 3),
      test_intervals = c(7, 10),
      sigma_within = 9,   # different from rec
      beta_eff = 0.6
    ),
    "sigma_within"
  )
})

test_that("invert_d2H_ensemble inherits the absolute default", {
  e <- suppressWarnings(invert_d2H_ensemble(
    d2H_wax = -180, d2H_wax_sd = 3,
    longitude = -90, latitude = 38,
    models = c("baseline", "baseline_sp"),
    verbose = FALSE
  ))
  per_site_sd <- as.numeric(apply(e$posterior_draws, 2, sd))
  expect_gt(per_site_sd, 5)
})

test_that("predict_d2h_precip uses absolute (paper-scale) intervals", {
  data(example_data, package = "leafwax")
  set.seed(11)
  res <- suppressWarnings(predict_d2h_precip(
    data = example_data[1, , drop = FALSE],
    model = "baseline_sp",
    progress = FALSE,
    verbose = FALSE
  ))
  expect_gt(res$prediction_interval_width, 30)
})
