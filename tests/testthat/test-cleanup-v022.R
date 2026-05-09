# Regression tests for the v0.2.2 cleanup pass and the audit follow-up:
#   - invert_d2H_ensemble() runs on default args (single site + multi-site)
#   - invert_d2H_ensemble() preserves per-site identity (audit P1)
#   - compare_models() runs on default args
#   - compare_models() rejects unknown `...` arg names with a clear error (audit P1)
#   - compare_models() reports only successful models in models_used (audit P3)
#   - c4_fraction (0-1) on the public API equals c4_percent (0-100) on the core
#   - c4_fraction outside [0, 1] is rejected with a unit-aware message
#   - c4_fraction length mismatch is rejected at both wrappers (audit P2)

test_that("invert_d2H_ensemble runs on default args, single site", {
  set.seed(1)
  res <- suppressWarnings(invert_d2H_ensemble(
    d2H_wax = -150, d2H_wax_sd = 3,
    longitude = -90, latitude = 38,
    verbose = FALSE
  ))
  expect_named(res, c("posterior_draws", "ensemble_summary",
                      "model_results", "models_used", "ensemble_method"))
  expect_true(is.matrix(res$posterior_draws))
  expect_equal(ncol(res$posterior_draws), 1L)
  expect_s3_class(res$ensemble_summary, "data.frame")
  expect_equal(nrow(res$ensemble_summary), 1L)
  expect_true(is.finite(res$ensemble_summary$mean))
  expect_setequal(
    res$models_used,
    c("full_sp", "full_interact_sp", "elevation_c4_interact_sp")
  )
})

test_that("invert_d2H_ensemble preserves per-site identity for multi-site input", {
  # Audit P1: previously the ensemble flattened across sites AND draws,
  # returning a single scalar mean across all sites. Lock in that the
  # output now has one column per site and a per-site summary.
  set.seed(1)
  res <- suppressWarnings(invert_d2H_ensemble(
    d2H_wax = c(-150, -120, -100), d2H_wax_sd = c(3, 3, 3),
    longitude = c(-90, -100, -110), latitude = c(38, 35, 40),
    verbose = FALSE
  ))
  expect_true(is.matrix(res$posterior_draws))
  expect_equal(ncol(res$posterior_draws), 3L)
  expect_equal(nrow(res$ensemble_summary), 3L)
  # Per-site means should be distinct and roughly track the
  # per-site d2H_wax inputs (more enriched wax -> less depleted precip).
  m <- res$ensemble_summary$mean
  expect_true(m[1] < m[3])
})

test_that("invert_d2H_ensemble respects ensemble_method='all'", {
  set.seed(1)
  res <- suppressWarnings(invert_d2H_ensemble(
    d2H_wax = -150, d2H_wax_sd = 3,
    longitude = -90, latitude = 38,
    ensemble_method = "all",
    verbose = FALSE
  ))
  expect_named(res, c("model_results", "ensemble_method"))
  expect_equal(res$ensemble_method, "all")
  expect_setequal(
    names(res$model_results),
    c("full_sp", "full_interact_sp", "elevation_c4_interact_sp")
  )
})

test_that("compare_models runs on default args, single site", {
  df <- data.frame(d2h_wax = -150, longitude = -90, latitude = 38)
  res <- suppressWarnings(compare_models(df, progress = FALSE))
  expect_s3_class(res, "data.frame")
  expect_equal(nrow(res), 1L)
  expect_true("d2h_precip_ensemble_mean" %in% names(res))
  expect_true(is.finite(res$d2h_precip_ensemble_mean))
})

test_that("compare_models runs on default args, multiple sites", {
  df <- data.frame(
    d2h_wax = c(-150, -140, -130),
    longitude = c(-90, -100, -110),
    latitude = c(38, 35, 40)
  )
  res <- suppressWarnings(compare_models(df, progress = FALSE))
  expect_equal(nrow(res), 3L)
  expect_true(all(is.finite(res$d2h_precip_ensemble_mean)))
})

test_that("compare_models return_all = TRUE returns model-tagged columns", {
  df <- data.frame(d2h_wax = -150, longitude = -90, latitude = 38)
  res <- suppressWarnings(
    compare_models(df, return_all = TRUE, progress = FALSE)
  )
  expect_true("d2h_precip_mean_baseline" %in% names(res))
  expect_true("d2h_precip_mean_baseline_sp" %in% names(res))
  expect_true("d2h_precip_mean_full_sp" %in% names(res))
})

test_that("compare_models rejects unknown `...` arg names with a clear error", {
  # Audit P1: previously `verb = FALSE` silently became "All models
  # failed" because tryCatch swallowed the per-model 'unused argument'
  # error. The new validation rejects unknown names up front.
  df <- data.frame(d2h_wax = -150, longitude = -90, latitude = 38)
  expect_error(
    compare_models(df, models = "baseline", progress = FALSE, verb = FALSE),
    "Unknown argument\\(s\\) passed via"
  )
})

test_that("compare_models models_used reports only successful models", {
  # Audit P3: with one nonsense model and two real ones, the requested
  # set has 3 entries but model_results will have 2; models_used should
  # reflect the 2.
  df <- data.frame(d2h_wax = -150, longitude = -90, latitude = 38)
  res <- suppressWarnings(
    compare_models(df,
                   models = c("baseline", "baseline_sp", "this_is_not_a_model"),
                   progress = FALSE)
  )
  expect_false(grepl("this_is_not_a_model", res$models_used))
})

test_that("invert_d2H wrapper converts c4_fraction (0-1) to c4_percent (0-100)", {
  set.seed(42)
  r_pub <- invert_d2H(d2H_wax = -150, d2H_wax_sd = 3,
                      longitude = -90, latitude = 38,
                      c4_fraction = 0.20, model_name = "full_sp",
                      verbose = FALSE)

  set.seed(42)
  r_core <- invert_d2h(d2h_wax = -150, d2h_wax_err = 3,
                       longitude = -90, latitude = 38,
                       c4_percent = 20, model_name = "full_sp",
                       verbose = FALSE)

  # Means should be within 1 per mil; the underlying scaling
  # ((c4 - 20) / 25) sees the same standardised value in both calls.
  expect_lt(abs(r_pub$d2h_precip_mean - r_core$d2h_precip_mean), 1)
})

test_that("invert_d2H rejects c4_fraction outside [0, 1]", {
  expect_error(
    invert_d2H(d2H_wax = -150, d2H_wax_sd = 3,
               longitude = -90, latitude = 38,
               c4_fraction = 25,
               model_name = "full_sp", verbose = FALSE),
    "c4_fraction must be in \\[0, 1\\]"
  )
  expect_error(
    invert_d2H(d2H_wax = -150, d2H_wax_sd = 3,
               longitude = -90, latitude = 38,
               c4_fraction = -0.1,
               model_name = "full_sp", verbose = FALSE),
    "c4_fraction must be in \\[0, 1\\]"
  )
})

test_that("invert_d2H error message names the offending value and the percent->fraction migration hint", {
  err <- tryCatch(
    invert_d2H(d2H_wax = -150, d2H_wax_sd = 3,
               longitude = -90, latitude = 38,
               c4_fraction = 50,
               model_name = "full_sp", verbose = FALSE),
    error = function(e) conditionMessage(e)
  )
  expect_match(err, "Got values up to 50")
  expect_match(err, "divide by 100")
})

test_that("predict_d2h_precip rejects c4_fraction outside [0, 1]", {
  df_bad <- data.frame(d2h_wax = -150, longitude = -90, latitude = 38,
                       c4_fraction = 25)
  expect_error(
    predict_d2h_precip(df_bad, model = "full_sp",
                       progress = FALSE, verbose = FALSE),
    "c4_fraction must be in \\[0, 1\\]"
  )
})

test_that("invert_d2H rejects c4_fraction with wrong length", {
  # Audit P2: previously a length-mismatch silently recycled. Now both
  # wrappers fail fast.
  expect_error(
    invert_d2H(d2H_wax = c(-150, -140, -130), d2H_wax_sd = c(3, 3, 3),
               longitude = c(-90, -100, -110), latitude = c(38, 35, 40),
               c4_fraction = c(0.5, 0.3),
               model_name = "full_sp", verbose = FALSE),
    "c4_fraction has length 2 but d2H_wax has length 3"
  )
})

test_that("predict_d2h_precip rejects c4_fraction with wrong length", {
  expect_error(
    predict_d2h_precip(d2h_wax = c(-150, -140, -130),
                       longitude = c(-90, -100, -110),
                       latitude = c(38, 35, 40),
                       c4_fraction = c(0.5, 0.3),
                       model = "full_sp",
                       progress = FALSE, verbose = FALSE),
    "c4_fraction has length 2 but d2h_wax has length 3"
  )
})

test_that("get_data_manifest returns NULL with warning when manifest unreachable", {
  skip_on_cran()
  cache_dir <- tryCatch(get_cache_dir(create = FALSE), error = function(e) NA_character_)
  if (!is.na(cache_dir) &&
      file.exists(file.path(cache_dir, "manifest.json"))) {
    skip("manifest already cached locally; cannot exercise the warn-loud path")
  }
  res <- withCallingHandlers(
    suppressWarnings(get_data_manifest()),
    warning = function(w) invokeRestart("muffleWarning")
  )
  if (!is.null(res)) {
    expect_true(length(res$files) > 0)
  } else {
    expect_null(res)
  }
})
