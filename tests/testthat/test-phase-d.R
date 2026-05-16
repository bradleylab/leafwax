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
    sigma_analytical  = 3,
    rho_t             = 0,
    confidence        = 0.95
  )
  out <- assess_claim(record = rec, claim = claim)
  expect_true(out$levels$passed[1])
  expect_false(out$levels$passed[2])
  expect_equal(out$highest_level, 1L)
})

test_that("assess_claim: corroborating proxies + integrity gates promote L1 → L2", {
  rec <- .make_record(delta_wax = 50)
  claim <- list(
    level                           = 4,
    interval_baseline               = c(0, 5000),
    interval_test                   = c(5000, 10000),
    sigma_analytical                = 3,
    rho_t                           = 0,
    confidence                      = 0.95,
    sediment_source_ruled_out       = list(value = TRUE,
                                           evidence = "grain size + mineralogy stable across interval"),
    depositional_artifact_ruled_out = list(value = TRUE,
                                           evidence = "continuous varved sequence; no erosional unconformity"),
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
    level                           = 4,
    interval_baseline               = c(0, 5000),
    interval_test                   = c(5000, 10000),
    sigma_analytical                = 3,
    rho_t                           = 0,
    confidence                      = 0.95,
    beta_eff                        = 0.55,
    magnitude_precip                = 30,
    sediment_source_ruled_out       = list(value = TRUE,
                                           evidence = "grain size + mineralogy stable"),
    depositional_artifact_ruled_out = list(value = TRUE,
                                           evidence = "continuous varved sequence"),
    corroborating_proxies           = list(speleothem = "concordant dry shift")
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
    level                           = 4,
    interval_baseline               = c(0, 5000),
    interval_test                   = c(5000, 10000),
    sigma_analytical                = 3,
    rho_t                           = 0,
    confidence                      = 0.95,
    beta_eff                        = 0.55,
    magnitude_precip                = 30,
    sediment_source_ruled_out       = list(value = TRUE,
                                           evidence = "grain size + mineralogy stable"),
    depositional_artifact_ruled_out = list(value = TRUE,
                                           evidence = "continuous varved sequence"),
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
    level                           = 3,
    interval_baseline               = c(0, 5000),
    interval_test                   = c(5000, 10000),
    sigma_analytical                = 3,
    confidence                      = 0.95,
    beta_eff                        = 0.55,
    # magnitude_precip intentionally omitted
    sediment_source_ruled_out       = list(value = TRUE,
                                           evidence = "stable"),
    depositional_artifact_ruled_out = list(value = TRUE,
                                           evidence = "continuous"),
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
                                         interval_test = c(1, 2))),
               "d2h_wax")  # missing age column
  bad_rec <- rec; bad_rec$age[3] <- NA_real_
  expect_error(assess_claim(record = bad_rec,
                            claim = list(level = 1,
                                         interval_baseline = c(0, 5000),
                                         interval_test = c(5000, 10000))),
               "non-finite")
})

test_that("assess_claim: empty / NA corroborating_proxies values do not pass L2", {
  rec <- .make_record(delta_wax = 50)
  base_claim <- list(
    level                           = 4,
    interval_baseline               = c(0, 5000),
    interval_test                   = c(5000, 10000),
    sigma_analytical                = 3,
    rho_t                           = 0,
    confidence                      = 0.95,
    sediment_source_ruled_out       = list(value = TRUE,
                                           evidence = "stable"),
    depositional_artifact_ruled_out = list(value = TRUE,
                                           evidence = "continuous")
  )
  # Empty string is not evidence.
  out_blank <- assess_claim(record = rec,
                            claim = c(base_claim,
                                      list(corroborating_proxies = list(speleothem = ""))))
  expect_false(out_blank$levels$passed[2])
  expect_match(out_blank$levels$summary[2], "empty/NA")

  # NA is not evidence.
  out_na <- assess_claim(record = rec,
                         claim = c(base_claim,
                                   list(corroborating_proxies = list(speleothem = NA))))
  expect_false(out_na$levels$passed[2])
  expect_match(out_na$levels$summary[2], "empty/NA")
})

test_that("assess_claim: NA stationarity evidence does not pass L4", {
  rec <- .make_record(delta_wax = 80)
  rec_recon <- .make_reconstruction(rec, delta_precip = -50)
  claim <- list(
    level                           = 4,
    interval_baseline               = c(0, 5000),
    interval_test                   = c(5000, 10000),
    sigma_analytical                = 3,
    rho_t                           = 0,
    confidence                      = 0.95,
    beta_eff                        = 0.55,
    magnitude_precip                = 30,
    sediment_source_ruled_out       = list(value = TRUE,
                                           evidence = "stable"),
    depositional_artifact_ruled_out = list(value = TRUE,
                                           evidence = "continuous"),
    corroborating_proxies           = list(speleothem = "concordant"),
    vegetation_stationary           = list(value = TRUE,
                                           evidence = NA_character_),
    seasonal_source_stationary    = list(value = TRUE,
                                         evidence = "speleothem stable"),
    evapotranspirative_stationary = list(value = TRUE,
                                         evidence = "leaf-water stable")
  )
  out <- assess_claim(record = rec, claim = claim,
                      reconstruction = rec_recon)
  expect_true(out$levels$passed[3])
  expect_false(out$levels$passed[4])
  expect_match(out$levels$summary[4], "vegetation_stationary")
})

test_that("assess_claim: invalid scalar fields error cleanly", {
  rec <- .make_record(delta_wax = 50)
  base_claim <- list(
    level             = 1,
    interval_baseline = c(0, 5000),
    interval_test     = c(5000, 10000)
  )
  expect_error(
    assess_claim(record = rec,
                 claim = c(base_claim, list(sigma_analytical = NA_real_))),
    "single finite numeric"
  )
  expect_error(
    assess_claim(record = rec,
                 claim = c(base_claim, list(rho_t = c(0.5, 0.6)))),
    "single finite numeric"
  )
  expect_error(
    assess_claim(record = rec,
                 claim = c(base_claim, list(confidence = "high"))),
    "single finite numeric"
  )
  expect_error(
    assess_claim(record = rec,
                 claim = c(base_claim, list(sigma_analytical = -1))),
    "non-negative"
  )
})

test_that("assess_claim: L1 threshold is invariant to rho_t", {
  # L1 threshold = z * sqrt(2) * sigma_analytical, independent of
  # rho_t. With sigma_analytical = 3 the threshold is ~8.3 permil
  # for every rho_t. A 5 permil shift is below it; a 10 permil
  # shift is above it.
  base_claim <- list(
    level             = 1,
    interval_baseline = c(0, 5000),
    interval_test     = c(5000, 10000),
    sigma_analytical  = 3,
    confidence        = 0.95
  )
  rec_small <- .make_record(delta_wax = 5)
  rec_large <- .make_record(delta_wax = 10)

  small_indep <- assess_claim(record = rec_small,
                              claim = c(base_claim, list(rho_t = 0)))
  small_corr  <- assess_claim(record = rec_small,
                              claim = c(base_claim, list(rho_t = 0.8)))
  large_indep <- assess_claim(record = rec_large,
                              claim = c(base_claim, list(rho_t = 0)))
  large_corr  <- assess_claim(record = rec_large,
                              claim = c(base_claim, list(rho_t = 0.8)))

  expect_false(small_indep$levels$passed[1])
  expect_false(small_corr$levels$passed[1])
  expect_true(large_indep$levels$passed[1])
  expect_true(large_corr$levels$passed[1])

  expect_equal(small_indep$details$L1$threshold_wax,
               small_corr$details$L1$threshold_wax,
               tolerance = 1e-10)
})

# ---- Level 2 path-b (vegetation envelope) and gate tests ----------------
# Manuscript §4.5.6 requires sediment-source and depositional artifact
# to be ruled out by independent evidence regardless of which Level 2
# path is used. Path (a) uses corroborating_proxies; path (b) uses
# level2_vegetation_path$vegetation_scenario + oipc_ref.

.l2_base_claim <- function(level = 2) {
  list(
    level                           = level,
    interval_baseline               = c(0, 5000),
    interval_test                   = c(5000, 10000),
    sigma_analytical                = 3,
    rho_t                           = 0,
    confidence                      = 0.95,
    sediment_source_ruled_out       = list(value = TRUE,
                                           evidence = "grain size + mineralogy stable"),
    depositional_artifact_ruled_out = list(value = TRUE,
                                           evidence = "continuous varved sequence")
  )
}

test_that("L2 requires sediment_source_ruled_out (gate failure blocks path a)", {
  rec <- .make_record(delta_wax = 50)
  # Both proxies supplied but sediment-source gate is FALSE.
  claim <- c(.l2_base_claim(),
             list(corroborating_proxies = list(speleothem = "concordant")))
  claim$sediment_source_ruled_out <- list(
    value = FALSE,
    evidence = "grain-size change suggests provenance shift"
  )
  out <- assess_claim(record = rec, claim = claim)
  expect_true(out$levels$passed[1])     # L1 still clears
  expect_false(out$levels$passed[2])    # L2 blocked by the gate
  expect_match(out$levels$summary[2],
               "integrity gates not satisfied")
  expect_match(out$levels$summary[2], "sediment_source_ruled_out")
})

test_that("L2 requires depositional_artifact_ruled_out (gate failure blocks path a)", {
  rec <- .make_record(delta_wax = 50)
  claim <- c(.l2_base_claim(),
             list(corroborating_proxies = list(speleothem = "concordant")))
  claim$depositional_artifact_ruled_out <- list(
    value = FALSE,
    evidence = "unconformity at the boundary"
  )
  out <- assess_claim(record = rec, claim = claim)
  expect_false(out$levels$passed[2])
  expect_match(out$levels$summary[2], "depositional_artifact_ruled_out")
})

test_that("L2 fails when gates pass but neither path attempted", {
  rec <- .make_record(delta_wax = 50)
  claim <- .l2_base_claim()
  out <- assess_claim(record = rec, claim = claim)
  expect_false(out$levels$passed[2])
  expect_match(out$levels$summary[2], "no Level 2 path attempted")
})

test_that("L2 path (b) passes when |delta_wax| > vegetation envelope", {
  # 50 permil wax shift far exceeds the envelope for a plausible
  # 30 percentage-point woody-to-grass transition; manuscript §4.5.3.
  rec <- .make_record(delta_wax = 50)
  claim <- c(.l2_base_claim(), list(
    oipc_ref = -60,
    level2_vegetation_path = list(
      vegetation_scenario = list(
        from = c(tree = 0.4, shrub = 0.3, grass = 0.2, C4 = 0.05),
        to   = c(tree = 0.1, shrub = 0.2, grass = 0.5, C4 = 0.20),
        evidence = "hypothetical 30-pp woody-to-grass scenario"
      )
    )
  ))
  out <- assess_claim(record = rec, claim = claim)
  expect_true(out$levels$passed[2])
  expect_match(out$levels$summary[2],
               "Vegetation-only null rejected")
  # §4.5.3 caveat must be present (verdict text must not over-claim).
  expect_match(out$levels$summary[2],
               "does not identify the hydroclimate mechanism")
  expect_match(out$levels$summary[2],
               "quantify precipitation")
  # Regression-guard: the deprecated phrasing must NOT appear.
  expect_false(grepl("non-vegetation hydroclimate interpretation warranted",
                     out$levels$summary[2]))
  # Sanity on the recorded envelope.
  expect_gt(out$details$L2$path_b_envelope$envelope_p975_abs, 0)
  expect_true(out$details$L2$path_b_passed)
})

test_that("L2 path (b) fails when |delta_wax| does not exceed envelope", {
  # Small wax shift over a 30 pp PFT-swing scenario: the envelope's
  # 97.5% upper bound exceeds the observed |delta_wax|, so the
  # vegetation-only null cannot be rejected. sigma_analytical = 1
  # lowers the L1 threshold to ~2.8 permil so the L1 gate clears
  # while |delta_wax| remains inside the envelope.
  rec <- .make_record(delta_wax = 4, sd_per_sample = 0.1)
  claim <- .l2_base_claim()
  claim$sigma_analytical <- 1
  claim <- c(claim, list(
    oipc_ref = -60,
    level2_vegetation_path = list(
      vegetation_scenario = list(
        from = c(tree = 0.1, shrub = 0.2, grass = 0.5, C4 = 0.20),
        to   = c(tree = 0.4, shrub = 0.3, grass = 0.2, C4 = 0.05),
        evidence = "hypothetical grass-to-woody scenario"
      )
    )
  ))
  out <- assess_claim(record = rec, claim = claim)
  expect_true(out$levels$passed[1])   # 4 permil > L1 threshold ~2.8
  expect_false(out$levels$passed[2])  # |Δwax|=4 < envelope ~5.7
  expect_match(out$levels$summary[2],
               "does not exceed vegetation-only envelope")
})

test_that("L2 path (b) verdict text does NOT contain the deprecated 'hydroclimate interpretation warranted' phrasing on any path", {
  # Regression-guard across both successful paths. The exact phrase
  # was removed during the magnitude-OR-evidence Level 2 redesign;
  # codex [FIX-2] flagged it as overclaiming.
  rec <- .make_record(delta_wax = 50)
  # Path (a)
  out_a <- assess_claim(rec, c(.l2_base_claim(),
                               list(corroborating_proxies =
                                      list(speleo = "concordant"))))
  # Path (b)
  out_b <- assess_claim(rec, c(.l2_base_claim(), list(
    oipc_ref = -60,
    level2_vegetation_path = list(
      vegetation_scenario = list(
        from = c(tree = 0.4, shrub = 0.3, grass = 0.2, C4 = 0.05),
        to   = c(tree = 0.1, shrub = 0.2, grass = 0.5, C4 = 0.20)
      )
    )
  )))
  expect_true(out_a$levels$passed[2])
  expect_true(out_b$levels$passed[2])
  expect_false(grepl("non-vegetation hydroclimate interpretation warranted",
                     out_a$levels$summary[2]))
  expect_false(grepl("non-vegetation hydroclimate interpretation warranted",
                     out_b$levels$summary[2]))
})

test_that("L2 path (b) propagates compute_vegetation_envelope() validation errors", {
  rec <- .make_record(delta_wax = 50)
  # Lowercase c4 — caught by compute_vegetation_envelope(); the message
  # surfaces in assess_claim's Level 2 summary as a path-b failure.
  claim <- c(.l2_base_claim(), list(
    oipc_ref = -60,
    level2_vegetation_path = list(
      vegetation_scenario = list(
        from = c(tree = 0.4, shrub = 0.3, grass = 0.2, c4 = 0.05),
        to   = c(tree = 0.1, shrub = 0.2, grass = 0.5, c4 = 0.20)
      )
    )
  ))
  out <- assess_claim(rec, claim)
  expect_false(out$levels$passed[2])
  expect_match(out$levels$summary[2],
               "envelope computation failed")
  expect_match(out$details$L2$path_b_error, "case-sensitive")
})
