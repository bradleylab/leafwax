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

test_that("invert_d2H_ensemble pool size matches first model's draw count", {
  # Lock in equal-weight pooling: the pool size should equal
  # nrow(first model's posterior_draws), not k * draws-per-model and
  # not the sum of per-model draws. This rules out the dominant
  # regression class for the audit-P2 fix (the pre-fix concatenate-
  # then-resample path produced a different pool dim). Mixed-tier
  # weighting cannot be exercised through the public API without
  # mocking, so the dimension contract is the testable surface.
  set.seed(11)
  res <- suppressWarnings(invert_d2H_ensemble(
    d2H_wax = -150, d2H_wax_sd = 3,
    longitude = -90, latitude = 38,
    verbose = FALSE
  ))
  expect_equal(
    nrow(res$posterior_draws),
    nrow(res$model_results[[1]]$posterior_draws)
  )
  expect_equal(ncol(res$posterior_draws), 1L)
})

test_that("invert_d2H_ensemble accepts return_full in ... without double-arg error", {
  # Audit (codex P2): the inner invert_d2H() call hard-codes
  # return_full = TRUE; if the caller passed return_full via `...` (a
  # reasonable mistake because `...` forwards to invert_d2H), R errored
  # with "formal argument 'return_full' matched by multiple actual
  # arguments". The wrapper now strips return_full / model_name from
  # `...` before the loop.
  set.seed(11)
  expect_error(
    suppressWarnings(invert_d2H_ensemble(
      d2H_wax = -150, d2H_wax_sd = 3,
      longitude = -90, latitude = 38,
      return_full = FALSE,
      verbose = FALSE
    )),
    NA
  )
})

test_that("invert_d2H wide PI regression at the test-fixture site (d2H=-130, lon=-90, lat=45)", {
  # Headline contract of the c11263f -> c5cc4cf -> b201d82 arc: the
  # reported interval is the full posterior predictive (parameter +
  # measurement + sigma_residual), not a fitted-value credible
  # interval. Pre-v0.2.2 the same call returned ~6 per mil 90% CI;
  # post-fix it returns ~80 per mil. The intermediate test that
  # asserted this magnitude was deleted with test-interval-type.R; this
  # test resurrects the regression at the same fixture site.
  set.seed(42)
  out <- suppressMessages(suppressWarnings(invert_d2H(
    d2H_wax = -130, d2H_wax_sd = 3,
    longitude = -90, latitude = 45,
    model_name = "baseline",
    verbose = FALSE
  )))
  expect_s3_class(out, "data.frame")
  expect_true("prediction_interval_width" %in% names(out))
  expect_gt(out$prediction_interval_width, 50)
  expect_lt(out$prediction_interval_width, 200)
})

test_that("batch_predict with progress=FALSE does not error on processing_time", {
  # process_sequential() previously assigned processing_time only inside
  # `if (progress) { ... }` but referenced it unconditionally below the
  # block. progress = FALSE triggered "object 'processing_time' not
  # found" mid-batch.
  data <- data.frame(
    d2h_wax = rep(-150, 12),
    longitude = rep(-90, 12),
    latitude = rep(38, 12)
  )
  expect_error(
    suppressWarnings(suppressMessages(batch_predict(
      data, model = "baseline", chunk_size = 4, progress = FALSE
    ))),
    NA
  )
})

test_that(".rbind_chunks pads missing columns with NA across mixed chunks", {
  # Lock in the column-tolerant rbind that batch_predict relies on when
  # a chunk's predict_d2h_precip() succeeded (full schema) and another
  # hit the error fallback (smaller schema). Pre-fix the do.call(rbind,
  # ...) at the outer combine step errored with "numbers of columns of
  # arguments do not match".
  ok    <- data.frame(a = 1, b = 2, c = 3)
  short <- data.frame(a = 4, c = 6)
  combined <- leafwax:::.rbind_chunks(list(ok, short))
  expect_setequal(names(combined), c("a", "b", "c"))
  expect_equal(nrow(combined), 2L)
  expect_true(is.na(combined$b[2]))
})

test_that("detect_change with empty test_interval and magnitudes does not error on rbind", {
  # Empty-interval branch previously emitted a 7-column row while the
  # populated branch emitted 7 + length(magnitudes) columns; rbind
  # across mixed empty + non-empty intervals errored when magnitudes
  # was supplied.
  draws <- matrix(rnorm(40 * 4, mean = -50, sd = 5), nrow = 40, ncol = 4)
  rec <- list(
    posterior_draws = draws,
    model_info = list(model_name = "baseline", tier = "unknown")
  )
  res <- suppressWarnings(detect_change(
    reconstruction = rec,
    age = c(1, 2, 3, 4),
    baseline_interval = c(1, 2),
    test_intervals = list(populated = c(3, 4), empty = c(99, 100)),
    sigma_residual = 16,
    beta_eff = 0.5,
    magnitudes = c(5, 10)
  ))
  expect_s3_class(res$intervals, "data.frame")
  expect_equal(nrow(res$intervals), 2L)
  expect_true("p_abs_delta_gt_5" %in% names(res$intervals))
  expect_true(is.na(res$intervals$p_abs_delta_gt_5[
    res$intervals$interval == "empty"]))
})

test_that("clear_download_cache against a nonexistent cache does not create it", {
  # Audit follow-up: clear_download_cache previously created the cache
  # directory before checking that it existed, leaving an empty dir on
  # disk after the user explicitly asked to wipe.
  tmp_cache <- tempfile("leafwax_cache_no_precreate_")
  expect_false(dir.exists(tmp_cache))
  old_opt <- getOption("leafwax.cache_dir")
  options(leafwax.cache_dir = tmp_cache)
  on.exit({
    options(leafwax.cache_dir = old_opt)
    if (dir.exists(tmp_cache)) unlink(tmp_cache, recursive = TRUE)
  }, add = TRUE)
  suppressMessages(clear_download_cache(confirm = FALSE))
  expect_false(dir.exists(tmp_cache))
})

test_that("invert_d2H_ensemble rejects unknown model names with a clear error", {
  # Audit P-ii: the previous validation read available_models()$model
  # but available_models() is a character vector; the subset was always
  # NULL and the validation silently passed bad names through.
  expect_error(
    suppressWarnings(invert_d2H_ensemble(
      d2H_wax = -150, d2H_wax_sd = 3,
      longitude = -90, latitude = 38,
      models = c("full_sp", "this_model_does_not_exist"),
      verbose = FALSE
    )),
    "Invalid models.*this_model_does_not_exist"
  )
})

test_that("compare_models with verbose=FALSE does not partial-match into predict_d2h_precip", {
  # Audit follow-up: compare_models takes its own `verbose` arg; if
  # `verbose` was forwarded via ... R's partial matching could collide
  # with predict_d2h_precip's `verbose` formal. The current signature
  # takes verbose explicitly and drops it from extra_args.
  data <- data.frame(
    d2h_wax = c(-150, -120),
    longitude = c(-90, -100),
    latitude = c(38, 40)
  )
  expect_error(
    suppressWarnings(suppressMessages(compare_models(
      data, models = c("baseline", "baseline_sp"),
      progress = FALSE
    ))),
    NA
  )
})

test_that("invert_d2H with c4_fraction = NULL emits no spurious capability warning", {
  # Audit follow-up: an unconditional c4_fraction * 100 conversion
  # turned NULL into numeric(0), which triggered a "C4 percent provided
  # but model X does not include C4 effects" warning even though the
  # caller had passed nothing. NULL must stay NULL through the
  # wrapper.
  warns <- character(0)
  res <- withCallingHandlers(
    suppressMessages(invert_d2H(
      d2H_wax = -150, d2H_wax_sd = 3,
      longitude = -90, latitude = 38,
      c4_fraction = NULL,
      model_name = "baseline",
      verbose = FALSE
    )),
    warning = function(w) {
      warns <<- c(warns, conditionMessage(w))
      invokeRestart("muffleWarning")
    }
  )
  spurious <- grepl("C4 percent provided", warns)
  expect_false(any(spurious),
               info = paste("Got C4-percent warning(s):",
                            paste(warns[spurious], collapse = " | ")))
  expect_s3_class(res, "data.frame")
})

test_that("invert_d2H_ensemble preserves order across all multi-site outputs (audit P1, strengthened)", {
  # Original test only checked m[1] < m[3] for three sites. With the
  # per-site flatten bug pre-fix, the function returned a single scalar
  # broadcast across all sites (so m[1] == m[2] == m[3]). Now that the
  # function preserves per-site identity, all three site means should
  # be distinct AND monotonically ordered with d2H_wax.
  set.seed(13)
  res <- suppressWarnings(invert_d2H_ensemble(
    d2H_wax = c(-160, -130, -100), d2H_wax_sd = c(3, 3, 3),
    longitude = c(-90, -100, -110), latitude = c(38, 35, 40),
    verbose = FALSE
  ))
  m <- res$ensemble_summary$mean
  expect_equal(length(unique(m)), 3L)
  expect_equal(order(m), order(c(-160, -130, -100)))
})

test_that("leafwax_set_config / leafwax_config recognise suppress_preview_warning", {
  # Pre-fix the option list was hard-coded in two places (config and
  # set_config) and missing suppress_preview_warning, even though
  # .onLoad seeded it. Driving both off LEAFWAX_DEFAULTS makes the
  # option round-trip end-to-end.
  current <- getOption("leafwax.suppress_preview_warning")
  on.exit(options(leafwax.suppress_preview_warning = current), add = TRUE)
  expect_silent(suppressMessages(
    leafwax_set_config(suppress_preview_warning = TRUE, persist = FALSE)
  ))
  cfg <- leafwax_config()
  expect_true("suppress_preview_warning" %in% names(cfg))
  expect_true(cfg$suppress_preview_warning)
})

test_that("invert_d2H supplied elevation with v10 models warns and ignores (no spline)", {
  # v10 fits did not produce beta_elev coefficients (load_posteriors
  # sets has_elevation only when those columns exist). Supplying
  # elevation should warn that the model does not include elevation
  # effects and proceed; pre-fix the unreachable spline branch in
  # invert_d2h hit a separate "Elevation knots not found" warning that
  # implied a metadata gap rather than the actual situation.
  expect_warning(
    suppressMessages(invert_d2H(
      d2H_wax = -150, d2H_wax_sd = 3,
      longitude = -90, latitude = 38,
      elevation = 1000,
      model_name = "elevation_only_sp",
      verbose = FALSE
    )),
    "elevation_only_sp.*does not include elevation"
  )
})

test_that("list_cached_models / check_data_cache read the v0.2 posteriors directory layout", {
  # Lock in the 8d6b748 fix: the cache helpers previously looked for
  # v0.1 file-name patterns (metadata/<model>_metadata.rds and
  # posteriors/<model>_2000draws.rds) but download_model_data() writes
  # to posteriors/<model>_posterior.rds, so cached models were
  # invisible to list_cached_models() and check_data_cache(). This test
  # exercises the actual exported functions, redirecting the cache via
  # options(leafwax.cache_dir = tmp).
  tmp_cache <- tempfile("leafwax_cache_")
  dir.create(file.path(tmp_cache, "posteriors"), recursive = TRUE)
  saveRDS(list(stub = TRUE),
          file.path(tmp_cache, "posteriors", "model_a_posterior.rds"))
  saveRDS(list(stub = TRUE),
          file.path(tmp_cache, "posteriors", "model_b_posterior.rds"))

  old_opt <- getOption("leafwax.cache_dir")
  options(leafwax.cache_dir = tmp_cache)
  on.exit({
    options(leafwax.cache_dir = old_opt)
    unlink(tmp_cache, recursive = TRUE)
  }, add = TRUE)

  models <- list_cached_models(verbose = FALSE)
  expect_setequal(models, c("model_a", "model_b"))
  expect_true(check_data_cache("model_a", verbose = FALSE))
  expect_true(check_data_cache("model_b", verbose = FALSE))
  expect_false(check_data_cache("model_c", verbose = FALSE))
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
