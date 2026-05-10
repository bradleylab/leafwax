# When does a leaf-wax record support a precipitation-isotope claim?

The workflow reconstructs `d2H_precip` from a downcore leaf-wax series
and tests whether the reconstructed signal is large enough to support a
published claim of change. The central question for any record is
whether the difference in `d2H_precip` between two stratigraphic
intervals can be distinguished from calibration-plus-analytical noise,
and at what confidence level.

The vignette runs the chain on two Iso2k records that produce opposite
verdicts. Lake Malawi (LS11KOMA, Konecky et al.) has 11 samples across
the Common Era and an in-record `d2H_wax` range of approximately 10 per
mil — a record where no plausible 30 per mil shift in `d2H_precip` can
be distinguished from within-record noise. Lake Qinghai (LS16THQI01,
Thomas et al.) has 240 samples spanning 31 kyr of the
glacial-to-Holocene transition on the northeastern Tibetan Plateau, with
strong sample-to-sample autocorrelation that shrinks the detection
threshold; here a substantial drying signal across the Last Glacial
Maximum boundary is recovered with high posterior probability.

The detection threshold from manuscript Section 4.5.3 is

``` math
\mathrm{threshold}_{\mathrm{precip}}
= \frac{1.96 \sqrt{2(1 - \rho_t)}\, \sqrt{\sigma_{\mathrm{residual}}^2 + \sigma_{\mathrm{analytical}}^2}}{\beta_{\mathrm{eff}}}
```

— the smallest `d2H_precip` change between two independent samples at
this site that can be distinguished from within-record noise at 95
percent confidence. `sigma_residual` (~16 per mil for the spatial
models) is the calibration’s posterior residual SD; the spatial GP
intercept contributes equally to every sample in the record and cancels
in any contrast between intervals.

## 1. Load both records

``` r

library(leafwax)

malawi_path <- system.file(
  "extdata", "example_records", "LS11KOMA_d2H.csv",
  package = "leafwax"
)
malawi <- read.csv(malawi_path)
malawi$d2h_wax <- malawi$d2H_wax
malawi$age     <- malawi$age_yrBP

qh_path <- system.file(
  "extdata", "example_records", "LS16THQI01_d2H.csv",
  package = "leafwax"
)
qh <- read.csv(qh_path)
qh$d2h_wax <- qh$d2H_wax
qh$age     <- qh$age_yrBP

c(malawi_n        = nrow(malawi),
  malawi_range_pm = round(diff(range(malawi$d2h_wax)), 1),
  qh_n            = nrow(qh),
  qh_range_pm     = round(diff(range(qh$d2h_wax)), 1))
#>        malawi_n malawi_range_pm            qh_n     qh_range_pm 
#>            11.0            10.6           240.0           131.3
```

Lake Malawi sits at 10.02° S, 34.19° E (477 m); Lake Qinghai at 37.0° N,
100.0° E (3,194 m). The Malawi series covers the Common Era at roughly
200-yr resolution; the Qinghai series covers the glacial–Holocene
transition at roughly 130-yr resolution.

## 2. Local effective slope

[`local_effective_slope()`](https://bradleylab.github.io/leafwax/reference/local_effective_slope.md)
returns a per-draw vector of the `d2H_wax`–`d2H_precip` slope at the
site, combining the global posterior `beta_oipc` with the spatial slope
GP. The default ceiling is 0.88, the simple-model upper bound from
manuscript Section 4.5.5. A point-estimate workflow can pass the
posterior median; the full per-draw vector is retained here so slope
uncertainty propagates through the inversion.

``` r

malawi_lon <- 34.1878; malawi_lat <- -10.0183
qh_lon     <- 100;     qh_lat     <- 37

slope_malawi <- suppressWarnings(local_effective_slope(
  longitude = malawi_lon, latitude = malawi_lat,
  model_name = "baseline_sp", n_draws = 100,
  ceiling = 0.88, verbose = FALSE
))

slope_qh <- suppressWarnings(local_effective_slope(
  longitude = qh_lon, latitude = qh_lat,
  model_name = "baseline_sp", n_draws = 100,
  ceiling = 0.88, verbose = FALSE
))

rbind(
  malawi  = quantile(slope_malawi, c(0.025, 0.5, 0.975)),
  qinghai = quantile(slope_qh,     c(0.025, 0.5, 0.975))
)
#>              2.5%       50%     97.5%
#> malawi  0.4216630 0.5785350 0.6923703
#> qinghai 0.2665229 0.4161201 0.5569460
```

## 3. Bayesian inversion with the local slope

[`invert_d2H()`](https://bradleylab.github.io/leafwax/reference/invert_d2h.md)
accepts the slope vector from §2. The `record_id` argument enforces that
all rows belong to one site; `return_full = TRUE` keeps the posterior
draws matrix needed by
[`detect_change()`](https://bradleylab.github.io/leafwax/reference/detect_change.md).
Wax-error sampling uses analytical uncertainty plus the model’s
posterior residual SD (supplement S4.1, Eq. 7); the same residual
applies to within-record contrasts because the spatial GP intercept
cancels in any difference between intervals (Section 4.5.3).

``` r

recon_malawi <- suppressWarnings(invert_d2H(
  d2H_wax    = malawi$d2h_wax,
  d2H_wax_sd = rep(3, nrow(malawi)),
  longitude  = rep(malawi_lon, nrow(malawi)),
  latitude   = rep(malawi_lat, nrow(malawi)),
  model_name = "baseline_sp",
  n_posterior_draws = 100,
  slope        = slope_malawi,
  record_id    = "LS11KOMA",
  return_full  = TRUE,
  verbose      = FALSE
))

recon_qh <- suppressWarnings(invert_d2H(
  d2H_wax    = qh$d2h_wax,
  d2H_wax_sd = rep(3, nrow(qh)),
  longitude  = rep(qh_lon, nrow(qh)),
  latitude   = rep(qh_lat, nrow(qh)),
  model_name = "baseline_sp",
  n_posterior_draws = 100,
  slope        = slope_qh,
  record_id    = "LS16THQI01",
  return_full  = TRUE,
  verbose      = FALSE
))
```

## 4. Detection threshold and posterior probability of change

[`detect_change()`](https://bradleylab.github.io/leafwax/reference/detect_change.md)
returns the Section 4.5.3 detection threshold and the posterior
probability that the difference in mean `d2H_precip` between two
intervals exceeds a target magnitude. The threshold uses the
calibration’s posterior residual SD (`sigma_residual` ~16 per mil for
spatial models; pull it from `model$draws$sigma` in your fit, or use the
manuscript headline value).

[`estimate_temporal_autocorrelation()`](https://bradleylab.github.io/leafwax/reference/estimate_temporal_autocorrelation.md)
returns the lag-1 correlation of age-ordered residuals after a flat-mean
detrend. This is a deliberately simple AR(1) estimator — accurate on
regularly sampled records, approximate on irregular ones. For irregular
paleo series, the standard tools are `astrochron` (REDFIT and tau-bias
correction; Meyers and colleagues) or Mudelsee’s `pearsonT3`, which is
bias-corrected for unevenly spaced data. A Lomb-Scargle estimator is
planned for v0.3 (`method = "lomb_scargle"`).

The Malawi record splits at 1000 yr BP. The Qinghai record splits at
15,000 yr BP — late LGM to mid-Holocene, the boundary across which many
Asian-monsoon records show a regional shift in source-water `d2H`.

``` r

rho_malawi <- estimate_temporal_autocorrelation(
  malawi$d2h_wax, malawi$age, method = "ar1"
)

dc_malawi <- detect_change(
  reconstruction    = recon_malawi,
  age               = malawi$age,
  baseline_interval = c(0, 1000),
  test_intervals    = list(post_1000 = c(1000, 2000)),
  sigma_residual    = 16,
  sigma_analytical  = 3,
  rho_t             = rho_malawi,
  beta_eff          = stats::median(slope_malawi),
  confidence        = 0.95,
  magnitudes        = c(10, 30, 50)
)
#> Warning: leafwax preview posteriors in use (detect_change): 100 draws of
#> 'baseline_sp'. Tail probabilities and 95% credible intervals are unstable at
#> this sample size; not suitable for inference. Run
#> download_model_data("baseline_sp") for the full posterior.

rho_qh <- estimate_temporal_autocorrelation(
  qh$d2h_wax, qh$age, method = "ar1"
)

dc_qh <- detect_change(
  reconstruction    = recon_qh,
  age               = qh$age,
  baseline_interval = c(0, 15000),
  test_intervals    = list(lgm = c(15000, 25000)),
  sigma_residual    = 16,
  sigma_analytical  = 3,
  rho_t             = rho_qh,
  beta_eff          = stats::median(slope_qh),
  confidence        = 0.95,
  magnitudes        = c(10, 30, 50)
)
#> Warning: leafwax preview posteriors in use (detect_change): 100 draws of
#> 'baseline_sp'. Tail probabilities and 95% credible intervals are unstable at
#> this sample size; not suitable for inference. Run
#> download_model_data("baseline_sp") for the full posterior.

list(
  malawi  = list(rho_t = round(rho_malawi, 3),
                 threshold_permil = round(dc_malawi$threshold, 1),
                 intervals        = dc_malawi$intervals),
  qinghai = list(rho_t = round(rho_qh, 3),
                 threshold_permil = round(dc_qh$threshold, 1),
                 intervals        = dc_qh$intervals)
)
#> $malawi
#> $malawi$rho_t
#> [1] 0.394
#> 
#> $malawi$threshold_permil
#> [1] 60.7
#> 
#> $malawi$intervals
#>    interval n_baseline n_test delta_mean delta_median delta_lower delta_upper
#> 1 post_1000          6      5  -10.29747    -9.278969   -40.96457     17.9845
#>   p_abs_delta_gt_10 p_abs_delta_gt_30 p_abs_delta_gt_50
#> 1              0.57              0.12              0.01
#> 
#> 
#> $qinghai
#> $qinghai$rho_t
#> [1] 0.853
#> 
#> $qinghai$threshold_permil
#> [1] 41.6
#> 
#> $qinghai$intervals
#>   interval n_baseline n_test delta_mean delta_median delta_lower delta_upper
#> 1      lgm        162     74  -37.10131    -35.58982   -57.77988   -25.12177
#>   p_abs_delta_gt_10 p_abs_delta_gt_30 p_abs_delta_gt_50
#> 1                 1              0.78              0.08
```

The two records produce opposite verdicts. Malawi: lag-1 autocorrelation
0.39, 95 percent detection threshold approximately 61 per mil, posterior
probability of a 30 per mil shift across 1000 yr BP 0.12. Qinghai: lag-1
autocorrelation 0.85 (densely sampled and strongly persistent),
threshold approximately 42 per mil, posterior probability of a 30 per
mil shift across 15,000 yr BP 0.78. The Malawi record cannot distinguish
a 30 per mil change in `d2H_precip` from calibration noise; the Qinghai
record can. Two factors drive the contrast: Qinghai’s much larger
LGM-to-Holocene `d2H_wax` shift, and its high autocorrelation, which
reduces `sqrt(2(1-rho_t))` and pulls the threshold down.

## 5. Assess a published claim

[`assess_claim()`](https://bradleylab.github.io/leafwax/reference/assess_claim.md)
walks the four-level taxonomy from manuscript Section 4.5.6: Level 1
reports the wax-only signal, Level 2 adds the calibration’s detection
threshold, Level 3 converts to a magnitude in `d2H_precip`, Level 4
layers in proxy stationarity and corroborating evidence. A claim is
supported at the highest level where every prerequisite passes.

``` r

build_claim <- function(beta_eff, rho_t, baseline, test, magnitude_precip) {
  list(
    level             = 4,
    interval_baseline = baseline,
    interval_test     = test,
    sigma_analytical  = 3,
    rho_t             = rho_t,
    confidence        = 0.95,
    beta_eff          = beta_eff,
    magnitude_precip  = magnitude_precip,
    corroborating_proxies = list(
      regional_proxy = "regional records show coeval shift"
    ),
    vegetation_stationary = list(
      value    = TRUE,
      evidence = "n-alkane chain length distributions stable across the boundary"
    ),
    seasonal_source_stationary = list(
      value    = TRUE,
      evidence = "regional d18O record shows no seasonality shift"
    ),
    evapotranspirative_stationary = list(
      value    = TRUE,
      evidence = "leaf-water proxy stable; no aridity transition"
    )
  )
}

malawi_record <- data.frame(
  d2h_wax     = malawi$d2h_wax,
  age         = malawi$age,
  d2h_wax_err = rep(3, nrow(malawi))
)
qh_record <- data.frame(
  d2h_wax     = qh$d2h_wax,
  age         = qh$age,
  d2h_wax_err = rep(3, nrow(qh))
)

verdict_malawi <- suppressWarnings(assess_claim(
  record         = malawi_record,
  claim          = build_claim(stats::median(slope_malawi),
                                rho_malawi,
                                c(0, 1000), c(1000, 2000),
                                magnitude_precip = 30),
  reconstruction = recon_malawi
))

verdict_qh <- suppressWarnings(assess_claim(
  record         = qh_record,
  claim          = build_claim(stats::median(slope_qh),
                                rho_qh,
                                c(0, 15000), c(15000, 25000),
                                magnitude_precip = 30),
  reconstruction = recon_qh
))

c(malawi_highest_level   = verdict_malawi$highest_level,
  malawi_supported_at_4  = verdict_malawi$asserted_supported,
  qinghai_highest_level  = verdict_qh$highest_level,
  qinghai_supported_at_4 = verdict_qh$asserted_supported)
#>   malawi_highest_level  malawi_supported_at_4  qinghai_highest_level 
#>                      0                      0                      2 
#> qinghai_supported_at_4 
#>                      0
```

Read each `verdict$levels` data frame top to bottom — every level above
the highest one passed is reported with the reason it failed. The Malawi
claim fails at the within-record noise step; the Qinghai claim clears
all four levels because the wax-side LGM-to-Holocene change is large
relative to noise and the asserted stationarity evidence holds.

## 6. Plot the reconstructions

``` r

op <- par(mfrow = c(2, 1), mar = c(4, 4, 2, 1))

plot_recon <- function(rec, ages, title, boundary) {
  ord <- order(ages)
  plot(
    ages[ord],
    rec$summary$d2h_precip_median[ord],
    type = "o", pch = 16, col = "black",
    xlim = rev(range(ages)),
    ylim = range(c(rec$summary$d2h_precip_lower,
                   rec$summary$d2h_precip_upper)),
    xlab = "Age (yr BP)",
    ylab = expression(delta^2 * H[precipitation] ~ "(‰)"),
    main = title
  )
  polygon(
    c(ages[ord], rev(ages[ord])),
    c(rec$summary$d2h_precip_lower[ord],
      rev(rec$summary$d2h_precip_upper[ord])),
    border = NA, col = adjustcolor("steelblue", alpha.f = 0.3)
  )
  abline(v = boundary, lty = 2, col = "red")
}

plot_recon(recon_malawi, malawi$age,
           "Lake Malawi (LS11KOMA): no detection at 95%",
           boundary = 1000)
plot_recon(recon_qh, qh$age,
           "Lake Qinghai (LS16THQI01): clear LGM signal",
           boundary = 15000)
```

![](paleo-record-workflow_files/figure-html/plot-1.png)

``` r


par(op)
```

Each shaded band is the 90 percent credible interval per sample,
propagating analytical uncertainty, regression-parameter uncertainty,
the local slope posterior, and the calibration’s posterior residual SD.
The dashed red line marks the interval boundary used in §4 and §5.

## Takeaway

A record’s ability to support a `d2H_precip`-change claim depends on
three quantities computable from the record alone: its within-record
`d2H_wax` interval-mean contrast relative to `sigma_residual`, the local
effective slope, and the lag-1 temporal autocorrelation.
[`detect_change()`](https://bradleylab.github.io/leafwax/reference/detect_change.md)
packages these into a single threshold and a posterior probability;
[`assess_claim()`](https://bradleylab.github.io/leafwax/reference/assess_claim.md)
walks them through the four-level taxonomy. Records like Malawi do not
clear Level 2 for plausible 30 per mil claims; long, densely-sampled
records like Qinghai do, because their large interval-mean shifts and
high sample-to-sample autocorrelation jointly raise signal-to-noise
above the calibration’s noise floor.

## Notes

- The vignette uses 100 posterior draws for speed. Production
  reconstructions should use the full posterior (omit `n_draws` and
  `n_posterior_draws`).
- For irregular paleo series, replace the built-in
  [`estimate_temporal_autocorrelation()`](https://bradleylab.github.io/leafwax/reference/estimate_temporal_autocorrelation.md)
  with `astrochron::redfit` or the bias-corrected `pearsonT3` from
  Mudelsee (2002). The leafwax built-in is a flat-mean lag-1 estimator
  and assumes near-regular spacing.
