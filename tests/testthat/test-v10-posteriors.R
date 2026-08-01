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

test_that("Bayesian inversion runs supported designs and refuses incomplete ones", {
  prior <- d2h_prior_normal(-70, 30)
  skip_if_preview_posteriors("baseline")
  supported <- c("baseline", "baseline_sp", "c4_only_sp")
  for (m in supported) {
    res <- invert_d2H(
      d2H_wax = -180, d2H_wax_sd = 3,
      longitude = -90, latitude = 38,
      c4_fraction = if (m == "c4_only_sp") 0.05 else NULL,
      model_name = m, prior = prior, n_posterior_draws = 80,
      verbose = FALSE
    )
    expect_s3_class(res, "leafwax_inverse")
    expect_true(is.finite(res$summary$d2h_precip_mean))
    expect_true(res$summary$d2h_precip_sd > 0)
    expect_lt(res$summary$d2h_precip_lower,
              res$summary$d2h_precip_upper)
  }
  for (m in setdiff(available_models(), supported)) {
    expect_error(
      invert_d2H(
        d2H_wax = -180, d2H_wax_sd = 3,
        longitude = -90, latitude = 38,
        model_name = m, prior = prior, verbose = FALSE
      ),
      "currently supports only"
    )
  }
})

test_that("spatial models give different predictions from non-spatial counterparts", {
  skip_if_preview_posteriors("baseline")
  args <- list(d2H_wax = -180, d2H_wax_sd = 3,
               longitude = -90, latitude = 38,
               prior = d2h_prior_normal(-70, 30),
               n_posterior_draws = 80, verbose = FALSE)
  ns <- do.call(invert_d2H, c(args, list(model_name = "baseline")))
  sp <- do.call(invert_d2H, c(args, list(model_name = "baseline_sp")))
  expect_false(isTRUE(all.equal(ns$summary$d2h_precip_mean,
                                sp$summary$d2h_precip_mean,
                                tolerance = 1e-3)),
               info = "baseline and baseline_sp returned identical predictions")
})
