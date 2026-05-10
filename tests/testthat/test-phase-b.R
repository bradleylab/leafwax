# Phase B tests: local_effective_slope() + slope override on invert_d2H().

test_that("local_effective_slope: spatial model returns per-draw vector", {
  s <- local_effective_slope(
    longitude = -90, latitude = 38,
    model_name = "baseline_sp",
    n_draws = 100, verbose = FALSE
  )
  expect_type(s, "double")
  expect_length(s, 100L)
  expect_true(all(is.finite(s)))
  # Spatial-model slope at one site should not be a single repeated value.
  expect_gt(stats::sd(s), 0)
})

test_that("local_effective_slope: non-spatial model returns global beta_oipc", {
  # baseline (no _sp) has no spatial slope perturbation, so the local
  # effective slope reduces to beta_oipc. Use all draws so we are not
  # comparing two different random subsets from load_posteriors().
  s_local <- local_effective_slope(
    longitude = -90, latitude = 38,
    model_name = "baseline",
    n_draws = NULL, verbose = FALSE
  )
  beta <- as.numeric(load_posteriors("baseline", n_draws = NULL,
                                     verbose = FALSE)$draws$beta_oipc)
  expect_equal(length(s_local), length(beta))
  expect_equal(s_local, beta, tolerance = 1e-10)
})

test_that("local_effective_slope: matches a hand-rolled extraction", {
  # Reproduce the function's output by calling predict_spatial_dual_gp
  # directly on the same draws.
  m <- load_posteriors("baseline_sp", n_draws = 50, verbose = FALSE)
  coords <- matrix(c(-90, 38), nrow = 1)
  dual <- predict_spatial_dual_gp(coords,
                                  m$spatial$knot_locs,
                                  m$draws,
                                  m$scaling)
  hand <- as.numeric(m$draws$beta_oipc) + as.numeric(dual$slope[, 1])

  # load_posteriors() uses deterministic stratified thinning, so the
  # public helper should be exactly the same posterior slice.
  s <- local_effective_slope(
    longitude = -90, latitude = 38,
    model_name = "baseline_sp",
    n_draws = 50, verbose = FALSE
  )

  expect_length(s, 50L)
  expect_true(all(is.finite(s)))
  expect_equal(s, hand, tolerance = 0)
})

test_that("local_effective_slope: returns raw posterior, no clipping", {
  # SPEC §3.3 / §6 invariant 4: the function must not clip, filter,
  # or otherwise modify the posterior draws. Draws above any
  # mechanistic reference (e.g. alpha = 0.88) must survive through
  # the public API unchanged.
  s <- local_effective_slope(
    longitude = -90, latitude = 38,
    model_name = "baseline_sp",
    n_draws = 200, verbose = FALSE
  )
  beta <- as.numeric(load_posteriors("baseline_sp", n_draws = 200,
                                     verbose = FALSE)$draws$beta_oipc)
  # The function must not expose a `ceiling` argument that would
  # induce post-hoc modification of the draws.
  expect_false("ceiling" %in% names(formals(local_effective_slope)))
  # Raw beta_oipc draws above 0.88 must propagate through the
  # public API without being clipped.
  if (any(beta > 0.88)) {
    expect_true(any(s > 0.88))
  }
})

test_that("local_effective_slope: override broadcasts cleanly", {
  # Single-value override: every draw is the same value, including
  # values that exceed any mechanistic reference - the package does
  # not second-guess the user's defended slope.
  s <- local_effective_slope(
    longitude = -90, latitude = 38,
    model_name = "baseline_sp",
    override = 0.95,
    n_draws = 100, verbose = FALSE
  )
  expect_true(all(s == 0.95))

  # Per-draw override is used per draw without modification.
  vec <- c(rep(0.4, 50), rep(0.95, 50))
  s2 <- local_effective_slope(
    longitude = -90, latitude = 38,
    model_name = "baseline_sp",
    override = vec,
    n_draws = 100, verbose = FALSE
  )
  expect_equal(sum(s2 == 0.4), 50L)
  expect_equal(sum(s2 == 0.95), 50L)
})

test_that("local_effective_slope: rejects bad inputs", {
  expect_error(
    local_effective_slope(longitude = c(-90, -89), latitude = 38,
                          model_name = "baseline_sp"),
    "single numeric"
  )
  expect_error(
    local_effective_slope(longitude = -90, latitude = "north",
                          model_name = "baseline_sp"),
    "single numeric"
  )
  expect_error(
    suppressWarnings(local_effective_slope(
      longitude = -90, latitude = 38,
      model_name = "baseline_sp",
      override = c(0.5, 0.6), n_draws = 100, verbose = FALSE
    )),
    "length 1 or length n_draws"
  )
})

test_that("invert_d2H: slope override propagates correctly", {
  args <- list(
    d2H_wax = -180, d2H_wax_sd = 3,
    longitude = -90, latitude = 38,
    model_name = "baseline_sp"
  )

  # With a smaller override slope, |inverted d2h_precip| should grow
  # because the inversion divides by a smaller number.
  set.seed(7)
  res_default <- suppressWarnings(do.call(invert_d2H, args))
  set.seed(7)
  res_low <- suppressWarnings(do.call(invert_d2H,
                                      c(args, list(slope = 0.3))))
  set.seed(7)
  res_high <- suppressWarnings(do.call(invert_d2H,
                                       c(args, list(slope = 0.85))))

  # Lower slope -> wider predictive SD (more uncertainty per per-mil
  # of wax noise after dividing).
  expect_lt(res_high$d2h_precip_sd, res_low$d2h_precip_sd)

  # Default and explicit overrides produce different point estimates
  # (because the override removes the per-draw spatial slope GP).
  expect_false(isTRUE(all.equal(res_default$d2h_precip_mean,
                                res_low$d2h_precip_mean,
                                tolerance = 1e-3)))
})

test_that("load_posteriors: subsampling is deterministic across calls", {
  # Two independent calls with the same model and n_draws must return
  # the same posterior subset, so local_effective_slope() and
  # invert_d2H() pair draws by position correctly.
  m1 <- load_posteriors("baseline_sp", n_draws = 60, verbose = FALSE)
  m2 <- load_posteriors("baseline_sp", n_draws = 60, verbose = FALSE)
  expect_identical(m1$draws$beta_oipc, m2$draws$beta_oipc)
  expect_identical(m1$draws[["z_intercept_spatial[1]"]],
                   m2$draws[["z_intercept_spatial[1]"]])
})

test_that("local_effective_slope output pairs correctly with invert_d2H", {
  # End-to-end alignment check: the slope vector built at n_draws = N
  # must be the same posterior thinning that invert_d2H consumes when
  # asked for n_posterior_draws = N.
  s <- local_effective_slope(
    longitude = -90, latitude = 38,
    model_name = "baseline_sp",
    n_draws = 80,
    verbose = FALSE
  )
  res <- suppressWarnings(invert_d2H(
    d2H_wax = -180, d2H_wax_sd = 3,
    longitude = -90, latitude = 38,
    model_name = "baseline_sp",
    slope = s,
    n_posterior_draws = 80
  ))
  expect_equal(nrow(res), 1L)
  expect_true(is.finite(res$d2h_precip_mean))
})

test_that("invert_d2H: zero / negative slope override rejected", {
  args <- list(
    d2H_wax = -180, d2H_wax_sd = 3,
    longitude = -90, latitude = 38,
    model_name = "baseline_sp"
  )

  expect_error(
    suppressWarnings(do.call(invert_d2H, c(args, list(slope = 0)))),
    "at or near zero"
  )
  expect_error(
    suppressWarnings(do.call(invert_d2H,
                             c(args, list(slope = c(0.5, 0, 0.6))))),
    "at or near zero"
  )
  expect_error(
    suppressWarnings(do.call(invert_d2H, c(args, list(slope = -0.5)))),
    "must be positive"
  )
})

test_that("invert_d2H: slope vector length validated", {
  args <- list(
    d2H_wax = -180, d2H_wax_sd = 3,
    longitude = -90, latitude = 38,
    model_name = "baseline_sp",
    slope = rep(0.55, 17)
  )
  expect_error(
    suppressWarnings(do.call(invert_d2H, args)),
    "length 1 or length n_draws"
  )

  args$slope <- c(0.5, NA_real_, 0.6)
  expect_error(
    suppressWarnings(do.call(invert_d2H, args)),
    "finite numeric"
  )
})
