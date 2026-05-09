# Phase A tests: invert_d2H argument-flow tests that don't depend on
# the retired sigma_within / estimate_sigma_within machinery. The
# manuscript and code now apply the calibration's posterior residual
# SD directly for both absolute and within-record use (manuscript
# Section 4.5.3); detection thresholds use that same sigma in
# detect_change(), so no separate within-record SD is needed.

test_that("invert_d2H: record_id triggers verbose acknowledgement and validates coords", {
  shared_args <- list(
    d2H_wax = rep(-180, 4),
    d2H_wax_sd = rep(3, 4),
    longitude = rep(-90, 4),
    latitude = rep(38, 4),
    model_name = "baseline_sp",
    record_id = "test_record"
  )

  msg <- capture.output(
    res <- suppressWarnings(do.call(invert_d2H, shared_args)),
    type = "output"
  )
  expect_true(any(grepl("downcore series", msg)))
  expect_equal(nrow(res), 4L)

  # Coordinate inconsistency under a constant record_id is an error.
  bad <- shared_args
  bad$longitude <- c(-90, -90, -89, -90)
  expect_error(
    suppressWarnings(do.call(invert_d2H, bad)),
    "longitude/latitude vary across rows"
  )

  # Multiple distinct record_ids are an error.
  multi <- shared_args
  multi$record_id <- c("a", "a", "b", "b")
  expect_error(
    suppressWarnings(do.call(invert_d2H, multi)),
    "single record per call"
  )
})
