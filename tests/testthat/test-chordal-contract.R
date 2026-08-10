# End-to-end contract tests for the chordal posterior deposit.

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
