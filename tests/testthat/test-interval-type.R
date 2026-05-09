# Behavior of interval_type = c("predictive", "fitted") in invert_d2H.
# The default ("predictive") includes the model's residual sigma in the
# reported interval; "fitted" returns a credible interval on the fitted
# value only. detect_change() and assess_claim() require "fitted" because
# the within-record contrast (manuscript Section 4.5.3) is derived under
# the assumption that the global residual SD is not in the posterior.

test_that("invert_d2H defaults to predictive: PI is markedly wider than fitted", {
  args <- list(
    d2H_wax = -180, d2H_wax_sd = 3,
    longitude = -90, latitude = 38,
    model_name = "baseline_sp"
  )
  set.seed(11)
  res_pred <- suppressWarnings(do.call(invert_d2H, args))
  set.seed(11)
  res_fit  <- suppressWarnings(do.call(invert_d2H,
                                       c(args, list(interval_type = "fitted"))))

  # Default flag should match "predictive"
  expect_identical(attr(res_pred, "leafwax_interval_type"), "predictive")
  expect_identical(attr(res_fit,  "leafwax_interval_type"), "fitted")

  # Predictive PI is wider; the gap is the residual sigma component
  expect_gt(res_pred$d2h_precip_sd, res_fit$d2h_precip_sd)
  expect_gt(res_pred$prediction_interval_width,
            res_fit$prediction_interval_width)
})

test_that("invert_d2H fitted-mode width recovers the pre-v022 narrow behavior", {
  # Regression case: at -130 wax / lon=-90 / lat=45 / baseline, the
  # fitted-line CI is ~6 per mil; the predictive PI is ~80-90 per mil.
  set.seed(7)
  res_fit <- suppressWarnings(invert_d2H(
    d2H_wax = -130, d2H_wax_sd = 1,
    longitude = -90, latitude = 45,
    model_name = "baseline",
    interval_type = "fitted",
    verbose = FALSE
  ))
  expect_lt(res_fit$prediction_interval_width, 12)

  set.seed(7)
  res_pred <- suppressWarnings(invert_d2H(
    d2H_wax = -130, d2H_wax_sd = 1,
    longitude = -90, latitude = 45,
    model_name = "baseline",
    interval_type = "predictive",
    verbose = FALSE
  ))
  expect_gt(res_pred$prediction_interval_width, 50)
  expect_lt(res_pred$prediction_interval_width, 150)
})

test_that("interval_type attr propagates through return_full = TRUE", {
  res <- suppressWarnings(invert_d2H(
    d2H_wax = -180, d2H_wax_sd = 3,
    longitude = -90, latitude = 38,
    model_name = "baseline_sp",
    return_full = TRUE,
    verbose = FALSE
  ))
  expect_identical(attr(res, "leafwax_interval_type"), "predictive")
  expect_identical(res$model_info$interval_type, "predictive")
})

test_that("detect_change rejects a reconstruction built with interval_type = predictive", {
  rec <- suppressWarnings(invert_d2H(
    d2H_wax = rep(-180, 10), d2H_wax_sd = rep(3, 10),
    longitude = rep(-90, 10), latitude = rep(38, 10),
    model_name = "baseline_sp",
    return_full = TRUE,
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
    "interval_type = \"fitted\""
  )
})

test_that("detect_change accepts a reconstruction built with interval_type = fitted", {
  rec <- suppressWarnings(invert_d2H(
    d2H_wax = rep(-180, 10), d2H_wax_sd = rep(3, 10),
    longitude = rep(-90, 10), latitude = rep(38, 10),
    model_name = "baseline_sp",
    return_full = TRUE,
    interval_type = "fitted",
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

test_that("invert_d2H_ensemble inherits the predictive default", {
  e <- suppressWarnings(invert_d2H_ensemble(
    d2H_wax = -180, d2H_wax_sd = 3,
    longitude = -90, latitude = 38,
    models = c("baseline", "baseline_sp"),
    verbose = FALSE
  ))
  # Ensemble pools predictive draws by default, so the per-site SD
  # should reflect the residual sigma component (well above the
  # measurement-only floor).
  per_site_sd <- as.numeric(apply(e$posterior_draws, 2, sd))
  expect_gt(per_site_sd, 5)
})

test_that("predict_d2h_precip uses predictive intervals (paper-scale CIs)", {
  data(example_data, package = "leafwax")
  set.seed(11)
  res <- suppressWarnings(predict_d2h_precip(
    data = example_data[1, , drop = FALSE],
    model = "baseline_sp",
    progress = FALSE,
    verbose = FALSE
  ))
  # Should match the predictive (residual-sigma-included) scale, not
  # the fitted scale.
  expect_gt(res$prediction_interval_width, 30)
})
