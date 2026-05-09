# Phase C tests: estimate_temporal_autocorrelation() + detect_change().

test_that("estimate_temporal_autocorrelation: recovers AR(1) rho on synthetic series", {
  set.seed(101)
  n <- 500
  rho_true <- 0.7
  e <- numeric(n); e[1] <- rnorm(1, 0, 5)
  for (k in 2:n) e[k] <- rho_true * e[k - 1] + rnorm(1, 0, 5 * sqrt(1 - rho_true^2))
  ag <- seq(0, 10000, length.out = n)
  d  <- -150 + e

  rho_hat <- estimate_temporal_autocorrelation(d, ag, method = "ar1")
  expect_type(rho_hat, "double")
  expect_true(is.finite(rho_hat))
  # Reasonable estimator quality on n=500.
  expect_gt(rho_hat, rho_true - 0.1)
  expect_lt(rho_hat, rho_true + 0.1)
})

test_that("estimate_temporal_autocorrelation: white noise gives rho near 0", {
  set.seed(102)
  n <- 500
  d  <- -150 + rnorm(n, 0, 5)
  ag <- seq(0, 10000, length.out = n)
  rho_hat <- estimate_temporal_autocorrelation(d, ag, method = "ar1")
  expect_lt(abs(rho_hat), 0.15)
})

test_that("estimate_temporal_autocorrelation: lomb_scargle is not yet implemented", {
  d  <- rnorm(20, -150, 5)
  ag <- seq(0, 5000, length.out = 20)
  expect_error(
    estimate_temporal_autocorrelation(d, ag, method = "lomb_scargle"),
    "not yet implemented"
  )
})

test_that("estimate_temporal_autocorrelation: warns on dropped non-finite rows", {
  set.seed(103)
  d  <- rnorm(50, -150, 5)
  ag <- seq(0, 5000, length.out = 50)
  d[c(7, 22)] <- NA_real_
  expect_warning(
    rho_hat <- estimate_temporal_autocorrelation(d, ag, method = "ar1"),
    "dropped 2 row"
  )
  expect_true(is.finite(rho_hat))
})

test_that("estimate_temporal_autocorrelation: rejects bad inputs", {
  expect_error(
    estimate_temporal_autocorrelation(c("a", "b"), c(1, 2)),
    "must be numeric"
  )
  expect_error(
    estimate_temporal_autocorrelation(1:5, 1:6),
    "same length"
  )
  expect_true(is.na(estimate_temporal_autocorrelation(1:2, 1:2)))
})

# Helper: build a plausible reconstruction object for detect_change().
.fake_reconstruction <- function(n_iter = 500, n_obs = 30,
                                 mean_baseline = -60, mean_test = -100,
                                 sd_per_sample = 10, seed = 1) {
  set.seed(seed)
  draws <- matrix(NA_real_, nrow = n_iter, ncol = n_obs)
  for (j in seq_len(n_obs)) {
    mu <- if (j <= n_obs / 2) mean_baseline else mean_test
    draws[, j] <- rnorm(n_iter, mu, sd_per_sample)
  }
  list(
    summary = NULL,
    posterior_draws = draws,
    model_info = list(model_name = "fake")
  )
}

test_that("detect_change: threshold matches the manuscript formula at rho_t = 0", {
  rec <- .fake_reconstruction()
  age <- seq(0, 10000, length.out = ncol(rec$posterior_draws))
  out <- detect_change(
    reconstruction    = rec,
    age               = age,
    baseline_interval = c(0, 5000),
    sigma_residual    = 16,
    sigma_analytical  = 3,
    rho_t             = 0,
    beta_eff          = 0.55,
    confidence        = 0.95
  )
  z <- stats::qnorm(0.975)
  expected <- z * sqrt(2 * 1) * sqrt(16^2 + 3^2) / 0.55
  expect_equal(out$threshold, expected, tolerance = 1e-10)
  # Manuscript headline number is ~81 permil at this combination
  # (the abstract reports 95% CI 67-105). Sanity-check the order
  # of magnitude.
  expect_gt(out$threshold, 70)
  expect_lt(out$threshold, 90)
})

test_that("detect_change: positive autocorrelation lowers the threshold", {
  rec <- .fake_reconstruction()
  age <- seq(0, 10000, length.out = ncol(rec$posterior_draws))
  args <- list(reconstruction = rec, age = age,
               baseline_interval = c(0, 5000),
               sigma_residual = 16, sigma_analytical = 3,
               beta_eff = 0.55, confidence = 0.95)
  t0 <- do.call(detect_change, c(args, list(rho_t = 0)))$threshold
  t5 <- do.call(detect_change, c(args, list(rho_t = 0.5)))$threshold
  t8 <- do.call(detect_change, c(args, list(rho_t = 0.8)))$threshold
  expect_lt(t5, t0)
  expect_lt(t8, t5)
  # Manuscript values: rho_t = 0 -> ~81; rho_t = 0.5 -> ~57;
  # rho_t = 0.8 -> ~36. Loose sanity bounds.
  expect_lt(abs(t5 - 57), 5)
  expect_lt(abs(t8 - 36), 5)
})

test_that("detect_change: posterior probability of change is sane", {
  # Baseline samples ~ Normal(-60, 10); test samples ~ Normal(-100, 10).
  # Posterior delta = mean(test) - mean(baseline) is concentrated near
  # -40, so Pr(|delta| > 30) should be high; Pr(|delta| > 80) low.
  rec <- .fake_reconstruction(mean_baseline = -60, mean_test = -100,
                              sd_per_sample = 10)
  age <- seq(0, 10000, length.out = ncol(rec$posterior_draws))
  out <- detect_change(
    reconstruction    = rec,
    age               = age,
    baseline_interval = c(0, 5000),
    test_intervals    = list(late = c(5000, 10000)),
    sigma_residual    = 5, sigma_analytical = 3,
    rho_t             = 0.5, beta_eff = 0.55, confidence = 0.95,
    magnitudes        = c(10, 30, 80)
  )
  expect_s3_class(out$intervals, "data.frame")
  expect_equal(out$intervals$interval, "late")
  expect_lt(out$intervals$delta_median, -30)
  expect_gt(out$intervals$delta_median, -50)
  expect_gt(out$intervals$p_abs_delta_gt_10, 0.95)
  expect_gt(out$intervals$p_abs_delta_gt_30, 0.5)
  expect_lt(out$intervals$p_abs_delta_gt_80, 0.05)
})

test_that("detect_change: rejects bad inputs", {
  rec <- .fake_reconstruction()
  age <- seq(0, 10000, length.out = ncol(rec$posterior_draws))

  expect_error(
    detect_change(reconstruction = list(), age = age,
                  baseline_interval = c(0, 5000),
                  sigma_residual = 5, beta_eff = 0.5),
    "posterior_draws"
  )
  expect_error(
    detect_change(reconstruction = rec, age = age[-1],
                  baseline_interval = c(0, 5000),
                  sigma_residual = 5, beta_eff = 0.5),
    "length n_samples"
  )
  expect_error(
    detect_change(reconstruction = rec, age = age,
                  baseline_interval = c(0, 5000),
                  sigma_residual = 5, beta_eff = 0),
    "non-zero"
  )
  expect_error(
    detect_change(reconstruction = rec, age = age,
                  baseline_interval = c(0, 5000),
                  sigma_residual = 5, beta_eff = 0.5,
                  rho_t = 1.5),
    "in \\(-1, 1\\)"
  )
  expect_error(
    detect_change(reconstruction = rec, age = age,
                  baseline_interval = c(0, 5000),
                  sigma_residual = -1, beta_eff = 0.5),
    "non-negative"
  )
})

test_that("detect_change: rejects non-finite ages up front", {
  rec <- .fake_reconstruction()
  age <- seq(0, 10000, length.out = ncol(rec$posterior_draws))
  age[5] <- NA_real_
  expect_error(
    detect_change(reconstruction = rec, age = age,
                  baseline_interval = c(0, 5000),
                  sigma_residual = 16, beta_eff = 0.55),
    "non-finite value"
  )
})

test_that("invert_d2H: return_full = TRUE forwards correctly", {
  res <- suppressWarnings(invert_d2H(
    d2H_wax = rep(-180, 4),
    d2H_wax_sd = rep(3, 4),
    longitude = rep(-90, 4),
    latitude = rep(38, 4),
    model_name = "baseline_sp",
    return_full = TRUE,
    n_posterior_draws = 50
  ))
  expect_type(res, "list")
  expect_true(!is.null(res$posterior_draws))
  expect_true(is.matrix(res$posterior_draws))
  expect_equal(ncol(res$posterior_draws), 4L)
})

test_that("detect_change: missing rho_t messages and defaults to 0", {
  rec <- .fake_reconstruction()
  age <- seq(0, 10000, length.out = ncol(rec$posterior_draws))
  expect_message(
    out <- detect_change(reconstruction = rec, age = age,
                         baseline_interval = c(0, 5000),
                         sigma_residual = 16, beta_eff = 0.55),
    "rho_t = 0"
  )
  expect_equal(out$formula$rho_t, 0)
})
