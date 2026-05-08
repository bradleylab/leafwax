# Phase D tests: assess_claim() walks the four-level taxonomy.

# Helper: synthesize a downcore record with two stratigraphic intervals
# and a configurable wax-space delta between them.
.make_record <- function(n = 30, baseline_age = c(0, 5000),
                         test_age = c(5000, 10000),
                         baseline_mu_wax = -180,
                         delta_wax = 0,
                         sd_per_sample = 1,
                         seed = 1) {
  set.seed(seed)
  age <- seq(baseline_age[1], test_age[2], length.out = n)
  is_test <- age >= test_age[1] & age <= test_age[2]
  mu  <- ifelse(is_test, baseline_mu_wax + delta_wax, baseline_mu_wax)
  data.frame(
    age         = age,
    d2h_wax     = mu + rnorm(n, 0, sd_per_sample),
    d2h_wax_err = rep(3, n)
  )
}

# Helper: build a paired reconstruction with a configurable
# d2H_precip-space delta between the same two intervals.
.make_reconstruction <- function(record,
                                 baseline_mu_precip = -50,
                                 delta_precip = -40,
                                 sd_per_sample = 5,
                                 n_iter = 800,
                                 seed = 2) {
  set.seed(seed)
  baseline_age <- c(min(record$age), median(record$age))
  is_test <- record$age > median(record$age)
  mu <- ifelse(is_test, baseline_mu_precip + delta_precip, baseline_mu_precip)
  draws <- matrix(NA_real_, nrow = n_iter, ncol = nrow(record))
  for (j in seq_len(nrow(record))) {
    draws[, j] <- rnorm(n_iter, mu[j], sd_per_sample)
  }
  list(summary = NULL, posterior_draws = draws,
       model_info = list(model_name = "fake"))
}

test_that("assess_claim: 5 permil wax shift, no corroboration, lands at L0/L1", {
  rec <- .make_record(delta_wax = 5)
  claim <- list(
    level             = 4,
    interval_baseline = c(0, 5000),
    interval_test     = c(5000, 10000),
    sigma_within      = 5,
    sigma_analytical  = 3,
    rho_t             = 0,
    confidence        = 0.95
  )
  out <- assess_claim(record = rec, claim = claim)
  # 5 permil delta vs ~16 permil threshold → L1 fails.
  expect_equal(out$highest_level, 0L)
  expect_false(out$asserted_supported)
  expect_false(out$levels$passed[1])
})

test_that("assess_claim: large wax shift clears L1 but no corroboration → L1 max", {
  rec <- .make_record(delta_wax = 50)
  claim <- list(
    level             = 4,
    interval_baseline = c(0, 5000),
    interval_test     = c(5000, 10000),
    sigma_within      = 5,
    sigma_analytical  = 3,
    rho_t             = 0,
    confidence        = 0.95
  )
  out <- assess_claim(record = rec, claim = claim)
  expect_true(out$levels$passed[1])
  expect_false(out$levels$passed[2])
  expect_equal(out$highest_level, 1L)
})

test_that("assess_claim: corroborating proxies promote L1 → L2", {
  rec <- .make_record(delta_wax = 50)
  claim <- list(
    level                 = 4,
    interval_baseline     = c(0, 5000),
    interval_test         = c(5000, 10000),
    sigma_within          = 5,
    sigma_analytical      = 3,
    rho_t                 = 0,
    confidence            = 0.95,
    corroborating_proxies = list(
      speleothem_d18O    = "matching dry shift in nearby cave",
      Br_Br_indicator_xrf = "marine vs terrestrial source consistent"
    )
  )
  out <- assess_claim(record = rec, claim = claim)
  expect_true(out$levels$passed[1])
  expect_true(out$levels$passed[2])
  expect_false(out$levels$passed[3])  # L3 needs beta_eff + magnitude_precip
  expect_equal(out$highest_level, 2L)
})

test_that("assess_claim: defended slope + magnitude reaches L3 when posterior agrees", {
  rec <- .make_record(delta_wax = 80)
  rec_recon <- .make_reconstruction(rec, delta_precip = -50, sd_per_sample = 5)
  claim <- list(
    level                 = 4,
    interval_baseline     = c(0, 5000),
    interval_test         = c(5000, 10000),
    sigma_within          = 5,
    sigma_analytical      = 3,
    rho_t                 = 0,
    confidence            = 0.95,
    beta_eff              = 0.55,
    magnitude_precip      = 30,
    corroborating_proxies = list(speleothem = "concordant dry shift")
  )
  out <- assess_claim(record = rec, claim = claim,
                      reconstruction = rec_recon)
  expect_true(out$levels$passed[1])
  expect_true(out$levels$passed[2])
  expect_true(out$levels$passed[3])
  expect_false(out$levels$passed[4])  # L4 needs stationarity evidence
  expect_equal(out$highest_level, 3L)
  expect_gt(out$details$L3$posterior_p_exceed, 0.95)
})

test_that("assess_claim: full stationarity evidence reaches L4", {
  rec <- .make_record(delta_wax = 80)
  rec_recon <- .make_reconstruction(rec, delta_precip = -50, sd_per_sample = 5)
  claim <- list(
    level                 = 4,
    interval_baseline     = c(0, 5000),
    interval_test         = c(5000, 10000),
    sigma_within          = 5,
    sigma_analytical      = 3,
    rho_t                 = 0,
    confidence            = 0.95,
    beta_eff              = 0.55,
    magnitude_precip      = 30,
    corroborating_proxies = list(speleothem = "concordant"),
    vegetation_stationary = list(value = TRUE,
                                 evidence = "biomarker chain length distributions stable across the interval"),
    seasonal_source_stationary = list(value = TRUE,
                                      evidence = "speleothem d18O shows no seasonality shift"),
    evapotranspirative_stationary = list(value = TRUE,
                                         evidence = "leaf-water proxy steady; no aridity transition")
  )
  out <- assess_claim(record = rec, claim = claim,
                      reconstruction = rec_recon)
  expect_true(out$levels$passed[4])
  expect_equal(out$highest_level, 4L)
  expect_true(out$asserted_supported)
})

test_that("assess_claim: missing L3 magnitude blocks promotion", {
  rec <- .make_record(delta_wax = 80)
  rec_recon <- .make_reconstruction(rec, delta_precip = -50)
  claim <- list(
    level                 = 3,
    interval_baseline     = c(0, 5000),
    interval_test         = c(5000, 10000),
    sigma_within          = 5,
    sigma_analytical      = 3,
    confidence            = 0.95,
    beta_eff              = 0.55,
    # magnitude_precip intentionally omitted
    corroborating_proxies = list(speleothem = "concordant")
  )
  out <- assess_claim(record = rec, claim = claim,
                      reconstruction = rec_recon)
  expect_false(out$levels$passed[3])
  expect_match(out$levels$summary[3], "missing required fields")
})

test_that("assess_claim: rejects bad inputs", {
  rec <- .make_record()
  expect_error(assess_claim(record = rec,
                            claim = list(level = 5)),
               "must be one of 1, 2, 3, 4")
  expect_error(assess_claim(record = list(d2h_wax = 1:5),
                            claim = list(level = 1,
                                         interval_baseline = c(0, 1),
                                         interval_test = c(1, 2),
                                         sigma_within = 5)),
               "d2h_wax")  # missing age column
  bad_rec <- rec; bad_rec$age[3] <- NA_real_
  expect_error(assess_claim(record = bad_rec,
                            claim = list(level = 1,
                                         interval_baseline = c(0, 5000),
                                         interval_test = c(5000, 10000),
                                         sigma_within = 5)),
               "non-finite")
})

test_that("assess_claim: rho_t > 0 lowers the L1 threshold", {
  rec <- .make_record(delta_wax = 12)
  base_claim <- list(
    level             = 1,
    interval_baseline = c(0, 5000),
    interval_test     = c(5000, 10000),
    sigma_within      = 5,
    sigma_analytical  = 3,
    confidence        = 0.95
  )
  out_independent <- assess_claim(record = rec,
                                  claim = c(base_claim, list(rho_t = 0)))
  out_correlated  <- assess_claim(record = rec,
                                  claim = c(base_claim, list(rho_t = 0.8)))
  # 12 permil delta is below the rho_t = 0 threshold but above the
  # rho_t = 0.8 threshold (sqrt(2*0.2) shrinks the threshold by ~63%).
  expect_false(out_independent$levels$passed[1])
  expect_true(out_correlated$levels$passed[1])
})
