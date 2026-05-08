# Smoke tests: every v10 model name in the manuscript loads and runs an
# inversion. Catches the routing layer drifting away from the shipped
# data files.

test_that("available_models() returns the 14 v10 names", {
  models <- available_models()
  expected <- c(
    "baseline", "baseline_sp",
    "baseline_env", "baseline_env_sp",
    "baseline_veg", "baseline_veg_sp",
    "full", "full_sp",
    "full_interact", "full_interact_sp",
    "elevation_only_sp", "elevation_c4_sp",
    "elevation_c4_interact_sp", "c4_only_sp"
  )
  expect_setequal(models, expected)
  expect_length(models, 14L)
})

test_that("each v10 model loads via load_posteriors()", {
  for (m in available_models()) {
    p <- load_posteriors(m, n_draws = 100, verbose = FALSE)
    expect_s3_class(p, "leafwax_posterior")
    expect_true(nrow(p$draws) > 0)
    expect_true(ncol(p$draws) > 0)
    if (p$metadata$has_gp) {
      expect_false(is.null(p$spatial))
      expect_true(nrow(p$spatial$knot_locs) > 0)
    }
  }
})

test_that("invert_d2H runs against every v10 model and returns finite predictions", {
  for (m in available_models()) {
    # Suppress capability-mismatch warnings: passing the full predictor
    # set to every model is intentional in this smoke test, and the
    # function's expected behavior is to warn and ignore unused inputs.
    res <- suppressWarnings(invert_d2H(
      d2H_wax = -180, d2H_wax_sd = 3,
      longitude = -90, latitude = 38,
      elevation = 200, c4_fraction = 0.05,
      pft_tree = 0.4, pft_shrub = 0.1, pft_grass = 0.3,
      model_name = m
    ))
    expect_s3_class(res, "data.frame")
    expect_equal(nrow(res), 1L)
    expect_true(is.finite(res$d2h_precip_mean),
                info = sprintf("mean is non-finite for model %s", m))
    expect_true(is.finite(res$d2h_precip_sd),
                info = sprintf("sd is non-finite for model %s", m))
    expect_true(res$d2h_precip_sd > 0,
                info = sprintf("sd is non-positive for model %s", m))
    expect_true(res$d2h_precip_lower < res$d2h_precip_upper,
                info = sprintf("CI bounds inverted for model %s", m))
  }
})

test_that("spatial models give different predictions from non-spatial counterparts", {
  args <- list(d2H_wax = -180, d2H_wax_sd = 3,
               longitude = -90, latitude = 38)
  ns <- do.call(invert_d2H, c(args, list(model_name = "baseline")))
  sp <- do.call(invert_d2H, c(args, list(model_name = "baseline_sp")))
  expect_false(isTRUE(all.equal(ns$d2h_precip_mean, sp$d2h_precip_mean,
                                tolerance = 1e-3)),
               info = "baseline and baseline_sp returned identical predictions")
})
