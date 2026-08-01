# Phase A tests: invert_d2H argument-flow tests that don't depend on
# the retired sigma_within / estimate_sigma_within machinery. The
# manuscript and code now apply the calibration's posterior residual
# SD directly for both absolute and within-record use (manuscript
# Section 4.5.3); detection thresholds use that same sigma in
# detect_change(), so no separate within-record SD is needed.

test_that("invert_d2H: record_id validates one shared-site joint record", {
  skip_if_preview_posteriors("baseline_sp")
  shared_args <- list(
    d2H_wax = rep(-180, 4),
    d2H_wax_sd = rep(3, 4),
    longitude = rep(-90, 4),
    latitude = rep(38, 4),
    model_name = "baseline_sp",
    record_id = "test_record",
    prior = d2h_prior_normal(-70, 30),
    n_posterior_draws = 80,
    verbose = FALSE
  )

  res <- suppressWarnings(do.call(invert_d2H, shared_args))
  expect_s3_class(res, "leafwax_inverse")
  expect_equal(nrow(res$summary), 4L)
  expect_equal(res$model_info$record_id, "test_record")

  # Coordinate inconsistency under a constant record_id is an error.
  bad <- shared_args
  bad$longitude <- c(-90, -90, -89, -90)
  expect_error(
    suppressWarnings(do.call(invert_d2H, bad)),
    "share longitude and latitude"
  )

  # Multiple distinct record_ids are an error.
  multi <- shared_args
  multi$record_id <- c("a", "a", "b", "b")
  expect_error(
    suppressWarnings(do.call(invert_d2H, multi)),
    "identify one record"
  )
})
