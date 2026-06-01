# Tests for compute_vegetation_envelope() — the magnitude path of the
# Level 2 claim taxonomy (manuscript §4.5.3).

# Reusable scenario where wax sums and PFT capitalization are valid.
.good_from <- c(tree = 0.4, shrub = 0.3, grass = 0.2, C4 = 0.05)
.good_to   <- c(tree = 0.1, shrub = 0.2, grass = 0.5, C4 = 0.20)
.good_oipc <- -60

test_that("compute_vegetation_envelope returns expected list shape", {
  env <- compute_vegetation_envelope(
    oipc_ref = .good_oipc, from = .good_from, to = .good_to,
    n_draws = 50, verbose = FALSE
  )
  expect_named(env,
    c("envelope_draws", "envelope_median", "envelope_p975_abs",
      "oipc_ref", "delta_pft", "n_draws_used", "model_name", "details"),
    ignore.order = FALSE
  )
  expect_length(env$envelope_draws, env$n_draws_used)
  expect_true(is.numeric(env$envelope_draws))
  expect_true(is.numeric(env$envelope_p975_abs))
  expect_equal(env$envelope_p975_abs,
               as.numeric(quantile(abs(env$envelope_draws), 0.975,
                                   names = FALSE)))
  expect_equal(env$envelope_median, median(env$envelope_draws))
  expect_equal(env$oipc_ref, .good_oipc)
  expect_named(env$delta_pft, c("tree", "shrub", "grass", "C4"))
  expect_equal(as.numeric(env$delta_pft),
               c(-0.3, -0.1, 0.3, 0.15),
               tolerance = 1e-12)
})

test_that("from == to gives envelope identically zero", {
  env <- compute_vegetation_envelope(
    oipc_ref = .good_oipc, from = .good_from, to = .good_from,
    n_draws = 50, verbose = FALSE
  )
  expect_equal(env$envelope_draws, rep(0, 50))
  expect_equal(env$envelope_median, 0)
  expect_equal(env$envelope_p975_abs, 0)
})

test_that("envelope scales linearly with ΔPFT magnitude", {
  # Doubling delta_pft (by doubling each component of `to - from`)
  # should double every per-draw envelope. Constructing two paired
  # scenarios on the same draws and comparing element-wise is the
  # cleanest test.
  small_from <- c(tree = 0.40, shrub = 0.30, grass = 0.20, C4 = 0.05)
  small_to   <- c(tree = 0.35, shrub = 0.25, grass = 0.30, C4 = 0.10)
  big_from   <- small_from
  big_to     <- small_from + 2 * (small_to - small_from)

  e1 <- compute_vegetation_envelope(.good_oipc, small_from, small_to,
                                    n_draws = 50, verbose = FALSE)
  e2 <- compute_vegetation_envelope(.good_oipc, big_from, big_to,
                                    n_draws = 50, verbose = FALSE)
  expect_equal(e2$envelope_draws, 2 * e1$envelope_draws,
               tolerance = 1e-8)
})

test_that("oipc_ref must be a finite scalar", {
  expect_error(
    compute_vegetation_envelope(oipc_ref = c(-60, -50),
                                from = .good_from, to = .good_to,
                                n_draws = 10, verbose = FALSE),
    "single finite numeric"
  )
  expect_error(
    compute_vegetation_envelope(oipc_ref = NA_real_,
                                from = .good_from, to = .good_to,
                                n_draws = 10, verbose = FALSE),
    "single finite numeric"
  )
})

test_that("PFT names are case-sensitive: c4 is rejected, C4 is required", {
  bad_from <- c(tree = 0.4, shrub = 0.3, grass = 0.2, c4 = 0.05)
  expect_error(
    compute_vegetation_envelope(oipc_ref = .good_oipc,
                                from = bad_from, to = .good_to,
                                n_draws = 10, verbose = FALSE),
    "case-sensitive"
  )
  # Missing required name.
  miss_from <- c(tree = 0.4, shrub = 0.3, grass = 0.2)
  expect_error(
    compute_vegetation_envelope(oipc_ref = .good_oipc,
                                from = miss_from, to = .good_to,
                                n_draws = 10, verbose = FALSE),
    "missing: C4"
  )
})

test_that("compositional validation catches from and to separately", {
  bad_sum_from <- c(tree = 0.6, shrub = 0.3, grass = 0.2, C4 = 0.1)
  expect_error(
    compute_vegetation_envelope(oipc_ref = .good_oipc,
                                from = bad_sum_from, to = .good_to,
                                n_draws = 10, verbose = FALSE),
    "`from` violates the compositional constraint"
  )
  bad_sum_to <- c(tree = 0.5, shrub = 0.4, grass = 0.4, C4 = 0.1)
  expect_error(
    compute_vegetation_envelope(oipc_ref = .good_oipc,
                                from = .good_from, to = bad_sum_to,
                                n_draws = 10, verbose = FALSE),
    "`to` violates the compositional constraint"
  )
})

test_that("values outside [0, 1] are rejected", {
  neg_from <- c(tree = -0.1, shrub = 0.3, grass = 0.2, C4 = 0.05)
  expect_error(
    compute_vegetation_envelope(oipc_ref = .good_oipc,
                                from = neg_from, to = .good_to,
                                n_draws = 10, verbose = FALSE),
    "in \\[0, 1\\]"
  )
})

test_that("model without all 8 PFT coefficients errors with the missing column names", {
  expect_error(
    compute_vegetation_envelope(oipc_ref = .good_oipc,
                                from = .good_from, to = .good_to,
                                model_name = "baseline_sp",
                                n_draws = 10, verbose = FALSE),
    "is missing required PFT coefficient column"
  )
  # The error message must specifically name at least one missing column.
  err <- tryCatch(
    compute_vegetation_envelope(oipc_ref = .good_oipc,
                                from = .good_from, to = .good_to,
                                model_name = "baseline_sp",
                                n_draws = 10, verbose = FALSE),
    error = function(e) conditionMessage(e)
  )
  expect_match(err, "beta_tree")
  expect_match(err, "beta_d2Hp_x_c4")
})

test_that("n_draws subsampling is deterministic", {
  # load_posteriors() uses a stratified deterministic thinning. Two
  # independent envelope calls with the same n_draws must produce
  # bit-identical draws.
  e1 <- compute_vegetation_envelope(.good_oipc, .good_from, .good_to,
                                    n_draws = 30, verbose = FALSE)
  e2 <- compute_vegetation_envelope(.good_oipc, .good_from, .good_to,
                                    n_draws = 30, verbose = FALSE)
  expect_identical(e1$envelope_draws, e2$envelope_draws)
})

test_that("envelope_p975_abs uses |envelope|, not signed envelope", {
  # A predominantly negative envelope must still produce a positive
  # envelope_p975_abs by construction. Pick a scenario where all PFT
  # coefficients drive the per-draw envelope negative on most draws.
  # The cleanest check: envelope_p975_abs must equal
  # quantile(abs(envelope_draws), 0.975) and be >= 0.
  env <- compute_vegetation_envelope(
    oipc_ref = .good_oipc,
    from = c(tree = 0.1, shrub = 0.2, grass = 0.5, C4 = 0.20),
    to   = c(tree = 0.4, shrub = 0.3, grass = 0.2, C4 = 0.05),
    n_draws = 100, verbose = FALSE
  )
  expect_gte(env$envelope_p975_abs, 0)
  expect_equal(env$envelope_p975_abs,
               as.numeric(quantile(abs(env$envelope_draws), 0.975,
                                   names = FALSE)))
  # If the signed envelope happens to be predominantly negative on
  # this scenario, envelope_p975_abs is still strictly positive and
  # the comparison |observed| > envelope_p975_abs is well-defined.
  expect_true(env$envelope_p975_abs > 0)
})
