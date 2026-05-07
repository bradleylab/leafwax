# Phase A tests: sigma_within argument flow + estimate_sigma_within().

test_that("estimate_sigma_within: stationary series gives sigma_within < global", {
  set.seed(42)
  n  <- 100
  ag <- seq(0, 10000, length.out = n)
  d  <- -160 + rnorm(n, 0, 5)
  est <- estimate_sigma_within(d, ag,
                               baseline_interval = c(0, 5000),
                               detrend = "none",
                               ar1_correction = TRUE)

  # Returned fields exist with the expected types.
  expect_type(est, "list")
  expect_named(est,
    c("sigma_within", "sigma_within_se", "sigma_naive",
      "n_baseline", "rho_t_baseline", "method"),
    ignore.order = TRUE)

  # sigma_within is positive, finite, and well below the global ~16 per mil.
  expect_true(is.finite(est$sigma_within) && est$sigma_within > 0)
  expect_lt(est$sigma_within, 10)

  # Half the points sit inside the baseline window.
  expect_equal(est$n_baseline, 50L)
})

test_that("estimate_sigma_within: full-record fallback emits the warning", {
  set.seed(43)
  d  <- rnorm(60, -180, 6)
  ag <- seq(0, 6000, length.out = 60)
  expect_warning(
    est <- estimate_sigma_within(d, ag,
                                 baseline_interval = NULL,
                                 detrend = "none",
                                 ar1_correction = FALSE),
    "treating the full record as the baseline"
  )
  expect_equal(est$n_baseline, 60L)
})

test_that("estimate_sigma_within: AR1 correction reduces sigma on autocorrelated series", {
  set.seed(44)
  n  <- 200
  ag <- seq(0, 10000, length.out = n)
  rho <- 0.85
  e  <- numeric(n)
  e[1] <- rnorm(1, 0, 5)
  for (k in 2:n) e[k] <- rho * e[k-1] + rnorm(1, 0, 5 * sqrt(1 - rho^2))
  d <- -150 + e

  with_ar1 <- estimate_sigma_within(d, ag,
                                    baseline_interval = c(0, 10000),
                                    detrend = "none",
                                    ar1_correction = TRUE)
  no_ar1   <- estimate_sigma_within(d, ag,
                                    baseline_interval = c(0, 10000),
                                    detrend = "none",
                                    ar1_correction = FALSE)
  expect_lt(with_ar1$sigma_within, no_ar1$sigma_within)
  # Recovered rho_t should be in the right ballpark.
  expect_gt(with_ar1$rho_t_baseline, 0.5)
})

test_that("estimate_sigma_within: linear detrend strips a trend", {
  set.seed(45)
  n  <- 80
  ag <- seq(0, 8000, length.out = n)
  d  <- -160 + 0.005 * ag + rnorm(n, 0, 4)   # 0.005 * 8000 = +40 trend
  no_detrend <- estimate_sigma_within(d, ag,
                                      baseline_interval = c(0, 8000),
                                      detrend = "none",
                                      ar1_correction = FALSE)
  with_detrend <- estimate_sigma_within(d, ag,
                                        baseline_interval = c(0, 8000),
                                        detrend = "linear",
                                        ar1_correction = FALSE)
  expect_lt(with_detrend$sigma_within, no_detrend$sigma_within)
})

test_that("estimate_sigma_within: rejects bad inputs", {
  expect_error(estimate_sigma_within(c("a", "b"), c(1, 2)),
               "must be numeric")
  expect_error(estimate_sigma_within(1:5, 1:6),
               "same length")
  expect_error(estimate_sigma_within(1:3, 1:3),
               "at least 4 finite")
  expect_error(estimate_sigma_within(1:10, seq_len(10),
                                     baseline_interval = 0),
               "length 2")
})

test_that("invert_d2H: sigma_within widens predictive uncertainty monotonically", {
  args <- list(
    d2H_wax = rep(-180, 5),
    d2H_wax_sd = rep(3, 5),
    longitude = rep(-90, 5),
    latitude = rep(38, 5),
    elevation = rep(200, 5),
    model_name = "baseline_sp"
  )

  set.seed(7)
  base_res <- suppressWarnings(do.call(invert_d2H, args))
  set.seed(7)
  small_res <- suppressWarnings(do.call(invert_d2H,
                                        c(args, list(sigma_within = 5))))
  set.seed(7)
  large_res <- suppressWarnings(do.call(invert_d2H,
                                        c(args, list(sigma_within = 25))))

  # Within-record noise should monotonically widen the predictive SD
  # at the same posterior draws.
  expect_lt(mean(base_res$d2h_precip_sd),
            mean(small_res$d2h_precip_sd))
  expect_lt(mean(small_res$d2h_precip_sd),
            mean(large_res$d2h_precip_sd))
})

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

test_that("invert_d2H: sigma_within validation rejects bad inputs", {
  args <- list(
    d2H_wax = -180, d2H_wax_sd = 3,
    longitude = -90, latitude = 38,
    model_name = "baseline_sp"
  )

  expect_error(
    suppressWarnings(do.call(invert_d2H,
                             c(args, list(sigma_within = -1)))),
    "non-negative"
  )
  expect_error(
    suppressWarnings(do.call(invert_d2H,
                             c(args, list(sigma_within = c(5, 10))))),
    "single non-negative"
  )
  expect_error(
    suppressWarnings(do.call(invert_d2H,
                             c(args, list(sigma_within_sd = 2)))),
    "supplied without sigma_within"
  )
})
