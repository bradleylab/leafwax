# Tests for local_effective_slope() and slope overrides on invert_d2H().

test_that("local_effective_slope: spatial model returns per-draw vector", {
  skip_if_preview_posteriors("baseline_sp")
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

test_that("local_effective_slope: non-spatial model returns physical global slope", {
  skip_if_preview_posteriors("baseline")
  # baseline (no _sp) has no spatial slope perturbation, so the local
  # effective slope reduces to beta_d2Hp. Use all draws so we are not
  # comparing two different random subsets from load_posteriors().
  s_local <- local_effective_slope(
    longitude = -90, latitude = 38,
    model_name = "baseline",
    n_draws = NULL, verbose = FALSE
  )
  model <- load_posteriors("baseline", n_draws = NULL, verbose = FALSE)
  beta <- leafwax:::.model_slope_to_physical(
    as.numeric(model$draws$beta_d2Hp), model$scaling
  )
  expect_equal(length(s_local), length(beta))
  expect_equal(s_local, beta, tolerance = 1e-10)
})

test_that("local_effective_slope: matches a hand-rolled extraction", {
  skip_if_preview_posteriors("baseline_sp")
  # Reproduce the function's output by calling predict_spatial_dual_gp
  # directly on the same draws.
  m <- load_posteriors("baseline_sp", n_draws = 50, verbose = FALSE)
  coords <- matrix(c(-90, 38), nrow = 1)
  dual <- predict_spatial_dual_gp(coords,
                                  m$spatial$knot_locs,
                                  m$draws,
                                  m$scaling,
                                  metric = m$metadata$spatial_metric)
  hand <- leafwax:::.model_slope_to_physical(
    as.numeric(m$draws$beta_d2Hp) + as.numeric(dual$slope[, 1]),
    m$scaling
  )

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

test_that("local_effective_slope: converts units without clipping posterior", {
  skip_if_preview_posteriors("baseline_sp")
  # The function must not clip, filter, or otherwise modify the posterior
  # draws. Draws above any
  # mechanistic reference (e.g. alpha = 0.88) must survive through
  # the public API unchanged.
  s <- local_effective_slope(
    longitude = -90, latitude = 38,
    model_name = "baseline_sp",
    n_draws = 200, verbose = FALSE
  )
  model <- load_posteriors("baseline_sp", n_draws = 200, verbose = FALSE)
  dual <- predict_spatial_dual_gp(
    matrix(c(-90, 38), nrow = 1),
    model$spatial$knot_locs,
    model$draws,
    model$scaling,
    metric = model$metadata$spatial_metric
  )
  expected <- leafwax:::.model_slope_to_physical(
    as.numeric(model$draws$beta_d2Hp) + as.numeric(dual$slope[, 1]),
    model$scaling
  )
  # The function must not expose a `ceiling` argument that would
  # induce post-hoc modification of the draws.
  expect_false("ceiling" %in% names(formals(local_effective_slope)))
  # The local field may shift every draw below a mechanistic reference at a
  # particular site. Compare to the complete hand calculation, not the global
  # coefficient alone, to test that no clipping occurred.
  expect_equal(s, expected, tolerance = 0)
})

test_that("slope unit conversions round trip exactly", {
  scaling <- list(d2H_sd = 38.576932, oipc_sd = 37.133244)
  fitted <- c(0.5, 0.7, 0.9)
  physical <- leafwax:::.model_slope_to_physical(fitted, scaling)

  expect_equal(
    leafwax:::.physical_slope_to_model(physical, scaling),
    fitted,
    tolerance = 1e-14
  )
  expect_equal(physical, fitted * 38.576932 / 37.133244)
})

test_that("physical slope override is restored to fitted-model units", {
  skip_if_preview_posteriors("baseline")
  model <- load_posteriors("baseline", n_draws = 40, verbose = FALSE)
  fitted <- as.numeric(model$draws$beta_d2Hp)
  physical <- leafwax:::.model_slope_to_physical(fitted, model$scaling)

  components <- leafwax:::.prepare_inverse_components(
    model = model,
    longitude = -90,
    latitude = 38,
    c4_percent = NULL,
    slope_override = physical
  )

  expect_equal(as.numeric(components$slope_standardized), fitted,
               tolerance = 1e-14)
})

test_that("local_effective_slope: override broadcasts cleanly", {
  skip_if_preview_posteriors("baseline_sp")
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
  skip_if_preview_posteriors("baseline_sp")
  expect_error(
    suppressWarnings(local_effective_slope(
      longitude = -90, latitude = 38,
      model_name = "baseline_sp",
      override = c(0.5, 0.6), n_draws = 100, verbose = FALSE
    )),
    "length 1 or length n_draws"
  )
})


test_that("load_posteriors: subsampling is deterministic across calls", {
  # Two independent calls with the same model and n_draws must return
  # the same posterior subset, so local_effective_slope() and
  # invert_d2H() pair draws by position correctly.
  m1 <- load_posteriors("baseline_sp", n_draws = 60, verbose = FALSE)
  m2 <- load_posteriors("baseline_sp", n_draws = 60, verbose = FALSE)
  expect_identical(m1$draws$beta_d2Hp, m2$draws$beta_d2Hp)
  expect_identical(m1$draws[["z_intercept_spatial[1]"]],
                   m2$draws[["z_intercept_spatial[1]"]])
})
