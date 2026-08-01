# End-to-end contract tests for the chordal-refit deposit bundle.
#
# The capability-flag tests in test-cleanup-v022.R verify that metadata flags
# have the right values. These tests verify the underlying DATA and PREDICTION
# behavior those flags describe, so that "tests pass" cannot be satisfied by
# flag arithmetic alone:
#   (A) every spatial deposit is stamped spatial_metric = "chordal" (a deposit
#       missing the stamp is silently predicted under the legacy standardized
#       metric -- the failure the chordal migration exists to prevent);
#   (B) every model that fitted an elevation spline actually carries the
#       beta_elev coefficients in its deposit, with real (nonzero-SD) draws --
#       guards against the converter dropping them as v2.0.0 did;
#   (C) the slope-based inversion is invariant to supplied elevation, so a
#       retained-but-not-consumed elevation coefficient cannot leak into a
#       reconstruction.

test_that("every spatial deposit is stamped with the chordal metric", {
  for (model_name in available_models()) {
    is_sp <- grepl("(^|_)sp$", model_name)
    loaded <- suppressWarnings(suppressMessages(
      load_posteriors(model_name, n_draws = 1, verbose = FALSE)
    ))$metadata
    if (is_sp) {
      expect_identical(loaded$spatial_metric, "chordal",
                       info = paste(model_name, "must be stamped chordal"))
    }
  }
})

test_that("elevation-fitting deposits carry beta_elev coefficients with real draws", {
  for (model_name in available_models()) {
    fitted_elev <- isTRUE(leafwax:::model_capability(model_name)$fitted_has_elevation)
    obj <- suppressWarnings(suppressMessages(
      load_posteriors(model_name, verbose = FALSE)
    ))
    elev_cols <- grep("^beta_elev", obj$metadata$parameters, value = TRUE)

    if (fitted_elev) {
      expect_true(length(elev_cols) >= 1L,
                  info = paste(model_name, "fitted elevation but deposit has no beta_elev column"))
      dm <- as.matrix(obj$draws[, elev_cols, drop = FALSE])
      sds <- apply(dm, 2, stats::sd)
      expect_true(any(sds > 0),
                  info = paste(model_name, "beta_elev columns are all constant (dropped/zeroed?)"))
    } else {
      expect_length(elev_cols, 0L)
    }
  }
})

test_that("inversion is invariant to supplied elevation (retained coefs not consumed)", {
  skip("Superseded: elevation-model inversion now fails closed.")
  # elevation_only_sp fits and now RETAINS beta_elev, but the slope-based
  # inversion must ignore it. A 4000 m elevation change must not move the
  # reconstruction. Seed each call identically so measurement-error draws match.
  # Use a data-dense site with a well-behaved (bounded-above-zero) local slope
  # so the check is about elevation invariance, not the separate near-zero-slope
  # invertibility limitation exercised in test-phase-b.
  set.seed(7)
  at_zero <- suppressWarnings(suppressMessages(invert_d2H(
    d2H_wax = -150, d2H_wax_sd = 3,
    longitude = 105, latitude = 30,
    elevation = 0, model_name = "elevation_only_sp",
    verbose = FALSE
  )))
  set.seed(7)
  at_4000 <- suppressWarnings(suppressMessages(invert_d2H(
    d2H_wax = -150, d2H_wax_sd = 3,
    longitude = 105, latitude = 30,
    elevation = 4000, model_name = "elevation_only_sp",
    verbose = FALSE
  )))
  expect_equal(at_zero$d2h_precip_mean, at_4000$d2h_precip_mean)
  expect_equal(at_zero$prediction_interval_width, at_4000$prediction_interval_width)
})

test_that("return_full reports elevation as NOT a used component for chordal elevation deposits", {
  skip("Superseded: elevation-model inversion now fails closed.")
  # The chordal deposit carries beta_elev columns (metadata$has_elevation TRUE),
  # but the slope-based inversion does not consume elevation, so the reported
  # components_used$elevation must be FALSE -- gated on the consumer capability
  # and whether the user supplied elevation, NOT on the deposit column flag.
  res <- suppressWarnings(suppressMessages(invert_d2H(
    d2H_wax = -150, d2H_wax_sd = 3,
    longitude = 105, latitude = 30,
    elevation = 2000, model_name = "elevation_only_sp",
    return_full = TRUE, verbose = FALSE
  )))
  expect_false(unname(res$model_info$components_used["elevation"]))
})
