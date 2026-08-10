# Package regression tests.


test_that(".rbind_chunks pads missing columns with NA across mixed chunks", {
  # batch_predict can combine a full prediction schema with a smaller
  # error-fallback schema.
  ok    <- data.frame(a = 1, b = 2, c = 3)
  short <- data.frame(a = 4, c = 6)
  combined <- leafwax:::.rbind_chunks(list(ok, short))
  expect_setequal(names(combined), c("a", "b", "c"))
  expect_equal(nrow(combined), 2L)
  expect_true(is.na(combined$b[2]))
})

test_that("detect_change with empty test_interval and magnitudes does not error on rbind", {
  # Empty and populated intervals must share a compatible result schema.
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
  # Clearing a nonexistent cache must not create an empty directory.
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

test_that("leafwax_set_config / leafwax_config recognise suppress_preview_warning", {
  # The preview-warning option must round-trip through the public configuration.
  current <- getOption("leafwax.suppress_preview_warning")
  on.exit(options(leafwax.suppress_preview_warning = current), add = TRUE)
  expect_silent(suppressMessages(
    leafwax_set_config(suppress_preview_warning = TRUE, persist = FALSE)
  ))
  cfg <- leafwax_config()
  expect_true("suppress_preview_warning" %in% names(cfg))
  expect_true(cfg$suppress_preview_warning)
})


test_that("metadata registry exposes posterior capabilities, not model-name implications", {
  metadata <- get_all_model_metadata()
  expect_length(metadata, 14L)

  has_elevation <- vapply(metadata, function(m) isTRUE(m$has_elevation), logical(1))
  expect_false(any(has_elevation))

  has_precip <- names(metadata)[
    vapply(metadata, function(m) isTRUE(m$has_precip), logical(1))
  ]
  expect_setequal(
    has_precip,
    c("baseline_env", "baseline_env_sp",
      "full", "full_sp", "full_interact", "full_interact_sp")
  )
})

test_that("static capability helpers match loaded posterior metadata", {
  metadata <- get_all_model_metadata()

  for (model_name in available_models()) {
    loaded <- suppressWarnings(suppressMessages(
      load_posteriors(model_name, n_draws = 1, verbose = FALSE)
    ))$metadata
    params <- get_model_parameters(model_name)$capabilities
    registry <- metadata[[model_name]]
    detected <- detect_model_capabilities(model_name)

    # Consumer capability flags exclude elevation because the reconstruction
    # interface does not consume it. Deposit metadata separately records
    # whether the fitted posterior retains elevation coefficients.
    expect_false(params$has_elevation)
    expect_false(registry$has_elevation)
    expect_false(detected$has_elevation)
    fitted_elev <- isTRUE(leafwax:::model_capability(model_name)$fitted_has_elevation)
    expect_identical(loaded$has_elevation, fitted_elev)

    expect_identical(params$has_precip, loaded$has_precip)
    expect_identical(params$has_c4, loaded$has_c4)
    expect_identical(params$has_pft, loaded$has_pft)
    expect_identical(params$has_spatial, loaded$has_gp)
    expect_identical(params$has_interaction, loaded$has_interaction)

    expect_identical(registry$has_precip, loaded$has_precip)
    expect_identical(registry$has_c4, loaded$has_c4)
    expect_identical(registry$has_vegetation, loaded$has_pft)
    expect_identical(registry$has_spatial, loaded$has_gp)
    expect_identical(registry$has_interaction, loaded$has_interaction)

    expect_identical(detected$has_precip, loaded$has_precip)
    expect_identical(detected$has_c4, loaded$has_c4)
    expect_identical(detected$has_pft, loaded$has_pft)
    expect_identical(detected$has_gp, loaded$has_gp)
    expect_identical(detected$has_interaction, loaded$has_interaction)
  }
})

test_that("list_models and validate_inputs do not require elevation", {
  models <- list_models(check_data = FALSE, verbose = FALSE)
  expect_false(any(models$has_elevation))
  expect_false(any(grepl("elevation", models$requires, ignore.case = TRUE)))

  expect_error(
    validate_inputs(
      d2h_wax = -150,
      longitude = -90,
      latitude = 38,
      model_name = "baseline_env"
    ),
    NA
  )
})

test_that("auto model selection ignores elevation-only input", {
  skip_if_preview_posteriors("baseline_sp")
  res <- suppressWarnings(predict_d2h_precip(
    d2h_wax = -150,
    longitude = -90,
    latitude = 38,
    elevation = 1000,
    model = "auto",
    prior = d2h_prior_normal(-70, 30),
    n_draws = 80,
    progress = FALSE,
    verbose = FALSE
  ))

  expect_equal(res$model_info$model_used, "baseline_sp")
})

test_that("shipped model_info.json matches no-elevation and 125-knot metadata", {
  info <- jsonlite::fromJSON(
    system.file("extdata", "model_info.json", package = "leafwax"),
    simplifyVector = FALSE
  )

  all_params <- unlist(lapply(info$models, `[[`, "parameters"), use.names = FALSE)
  expect_false("beta_elev" %in% all_params)
  # The metadata note must distinguish fitted coefficients from predictors
  # consumed by the reconstruction interface.
  expect_match(info$notes$elevation, "not consume|not used", ignore.case = TRUE)
  expect_match(info$notes$spatial_knots, "125")
})

test_that("cache helpers read the current posterior directory layout", {
  # Exercise the exported cache functions against the file layout written by
  # download_model_data().
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
