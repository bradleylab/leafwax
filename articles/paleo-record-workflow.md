# When does a leaf-wax record support a precipitation-isotope claim?

The workflow reconstructs `d2H_precip` from a downcore leaf-wax series
and tests whether the reconstructed signal is large enough to support a
published claim of change. The central question for any record is
whether the difference in `d2H_precip` between two stratigraphic
intervals can be distinguished from calibration-plus-analytical noise,
and at what confidence level.

The vignette runs the chain on two Iso2k records with different signal
sizes and sampling structures. The package ships small CSV extracts for
the examples, and the source records remain available from LiPDverse and
NOAA/WDS Paleoclimatology:

| Package file | Iso2k record | Source study | Data archive |
|----|----|----|----|
| `LS14FEZA_d2H.csv` | [LS14FEZA](https://lipdverse.org/iso2k/1_0_0/LS14FEZA.html), [LiPD](https://lipdverse.org/iso2k/1_0_0/LS14FEZA.lpd) | Feakins et al. (2014), [doi:10.1016/j.orggeochem.2013.10.015](https://doi.org/10.1016/j.orggeochem.2013.10.015) | NOAA/WDS, [doi:10.25921/13bn-nd37](https://doi.org/10.25921/13bn-nd37) |
| `LS16THQI01_d2H.csv` | [LS16THQI01](https://lipdverse.org/iso2k/1_0_0/LS16THQI01.html), [LiPD](https://lipdverse.org/iso2k/1_0_0/LS16THQI01.lpd) | Thomas et al. (2016), [doi:10.1016/j.quascirev.2015.11.003](https://doi.org/10.1016/j.quascirev.2015.11.003) | NOAA/WDS, [doi:10.25921/mnzv-kp03](https://doi.org/10.25921/mnzv-kp03) |

The Iso2k compilation is archived at
[doi:10.25921/57j8-vs18](https://doi.org/10.25921/57j8-vs18).

The per-sample detection threshold used by
[`detect_change()`](https://bradleylab.github.io/leafwax/reference/detect_change.md)
is

``` math
\mathrm{threshold}_{\mathrm{precip}}
= \frac{1.96 \sqrt{2(1 - \rho_t)}\, \sqrt{\sigma_{\mathrm{residual}}^2 + \sigma_{\mathrm{analytical}}^2}}{\beta_{\mathrm{eff}}}
```

where `rho_t` is the lag-1 temporal autocorrelation, `sigma_residual` is
the calibration residual SD on the wax scale, `sigma_analytical` is the
analytical uncertainty on the wax measurements, and `beta_eff` is the
local effective slope. This is the smallest `d2H_precip` change between
two independent samples at this site that can be distinguished from
within-record noise at 95 percent confidence. The spatial GP intercept
contributes equally to every sample in the record and cancels in any
contrast between intervals.

## 1. Load both records

``` r

library(leafwax)

example_record_path <- function(filename) {
  installed_path <- system.file(
    "extdata", "example_records", filename,
    package = "leafwax"
  )
  if (nzchar(installed_path)) {
    return(installed_path)
  }

  source_paths <- file.path(
    c("inst", file.path("..", "inst")),
    "extdata", "example_records", filename
  )
  source_path <- source_paths[file.exists(source_paths)][1]
  if (!is.na(source_path)) {
    return(source_path)
  }

  stop("Could not locate example record: ", filename, call. = FALSE)
}

zaca_path <- example_record_path("LS14FEZA_d2H.csv")
zaca <- read.csv(zaca_path)
zaca$d2h_wax <- zaca$d2H_wax
zaca$age     <- zaca$age_yrBP

qh_path <- example_record_path("LS16THQI01_d2H.csv")
qh <- read.csv(qh_path)
qh$d2h_wax <- qh$d2H_wax
qh$age     <- qh$age_yrBP

c(zaca_n        = nrow(zaca),
  zaca_range_pm = round(diff(range(zaca$d2h_wax)), 1),
  qh_n            = nrow(qh),
  qh_range_pm     = round(diff(range(qh$d2h_wax)), 1))
#>        zaca_n zaca_range_pm          qh_n   qh_range_pm 
#>         518.0          77.0         240.0         131.3
```

Zaca Lake sits at 34.78° N, 120.04° W (730 m) on the southern California
coast; Lake Qinghai at 37.0° N, 100.0° E (3,194 m) on the northeastern
Tibetan Plateau. The Zaca series covers the last 3 kyr at roughly 6-yr
resolution; the Qinghai series covers the glacial–Holocene transition at
roughly 130-yr resolution.

## 2. Plot the leaf-wax records

Before estimating a precipitation-isotope signal, inspect the measured
`d2H_wax` series and the interval boundaries used below.

``` r

op <- par(mfrow = c(2, 1), mar = c(4, 4, 2, 1))

plot_wax <- function(record, title, boundary) {
  ord <- order(record$age)
  plot(
    record$age[ord],
    record$d2h_wax[ord],
    type = "o", pch = 16, col = "black",
    xlim = rev(range(record$age)),
    xlab = "Age (yr BP)",
    ylab = expression(delta^2 * H[wax] ~ "(‰)"),
    main = title
  )
  abline(v = boundary, lty = 2, col = "red")
}

plot_wax(zaca, "Zaca Lake (LS14FEZA)", boundary = 1000)
plot_wax(qh, "Lake Qinghai (LS16THQI01)", boundary = 15000)
```

![](paleo-record-workflow_files/figure-html/plot-wax-1.png)

``` r


par(op)
```

The dashed red lines mark the same interval boundaries used in the
change-detection and claim-assessment examples.

## 3. Claim levels used by `assess_claim()`

[`assess_claim()`](https://bradleylab.github.io/leafwax/reference/assess_claim.md)
reports the highest claim level supported by the record and the supplied
evidence. A level only passes if every lower level has also passed.

| Level | Claim being made | What must be supplied or demonstrated |
|----|----|----|
| 1 | A leaf-wax `d2H` change occurred between two intervals. | The interval-mean wax contrast exceeds analytical uncertainty at the chosen confidence level, after the requested `rho_t` adjustment. |
| 2 | The wax change is consistent with a directional hydroclimate change. | Level 1 passes and `corroborating_proxies` contains named, non-empty evidence. |
| 3 | The wax change supports a quantitative `d2H_precip` magnitude. | Level 2 passes, a defended `beta_eff` is supplied, the full inversion posterior is available, and the posterior probability of exceeding `magnitude_precip` meets the requested confidence level. |
| 4 | The quantitative magnitude is uniquely attributable to precipitation isotopes. | Level 3 passes and independent evidence supports stationary vegetation, source-water seasonality, and evapotranspirative enrichment over the interval. |

The functions enforce the structure of the evidence fields. They do not
decide whether a proxy interpretation or stationarity argument is
scientifically adequate; that still requires record-specific evidence
and citations.

## 4. Local effective slope

[`local_effective_slope()`](https://bradleylab.github.io/leafwax/reference/local_effective_slope.md)
returns posterior draws for the site-specific `d2H_wax`-`d2H_precip`
slope, combining the global posterior `beta_oipc` with the spatial slope
GP. The function does not apply a ceiling or otherwise filter the draws.
Passing the full vector to
[`invert_d2H()`](https://bradleylab.github.io/leafwax/reference/invert_d2h.md)
propagates slope uncertainty through the reconstruction; passing a
scalar, such as the posterior median, gives a point-slope sensitivity
run.

``` r

zaca_lon <- -120.0392; zaca_lat <- 34.7778
qh_lon     <- 100;     qh_lat     <- 37

slope_zaca <- suppressWarnings(local_effective_slope(
  longitude = zaca_lon, latitude = zaca_lat,
  model_name = "baseline_sp", n_draws = 100,
  verbose = FALSE
))

slope_qh <- suppressWarnings(local_effective_slope(
  longitude = qh_lon, latitude = qh_lat,
  model_name = "baseline_sp", n_draws = 100,
  verbose = FALSE
))

rbind(
  zaca  = quantile(slope_zaca, c(0.025, 0.5, 0.975)),
  qinghai = quantile(slope_qh,     c(0.025, 0.5, 0.975))
)
#>              2.5%       50%     97.5%
#> zaca    0.4158966 0.5744484 0.7357822
#> qinghai 0.2665229 0.4161201 0.5569460
```

## 5. Bayesian inversion with the local slope

[`invert_d2H()`](https://bradleylab.github.io/leafwax/reference/invert_d2h.md)
accepts the slope vector from the previous section. The `record_id`
argument enforces that all rows belong to one site; `return_full = TRUE`
keeps the posterior draws matrix needed by
[`detect_change()`](https://bradleylab.github.io/leafwax/reference/detect_change.md).
Wax-error sampling uses analytical uncertainty plus the model’s
posterior residual SD; the same residual applies to within-record
contrasts because the spatial GP intercept cancels in any difference
between intervals.

``` r

recon_zaca <- suppressWarnings(invert_d2H(
  d2H_wax    = zaca$d2h_wax,
  d2H_wax_sd = rep(3, nrow(zaca)),
  longitude  = rep(zaca_lon, nrow(zaca)),
  latitude   = rep(zaca_lat, nrow(zaca)),
  model_name = "baseline_sp",
  n_posterior_draws = 100,
  slope        = slope_zaca,
  record_id    = "LS14FEZA",
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

## 6. Detection threshold and posterior probability of change

[`detect_change()`](https://bradleylab.github.io/leafwax/reference/detect_change.md)
returns the per-sample detection threshold and the posterior probability
that the difference in mean `d2H_precip` between two intervals exceeds a
target magnitude. The example below passes `sigma_residual = 16`, the
residual scale used for the package’s spatial-model examples; for a full
analysis, use the residual SD from the fitted calibration being
propagated.

[`estimate_temporal_autocorrelation()`](https://bradleylab.github.io/leafwax/reference/estimate_temporal_autocorrelation.md)
returns the lag-1 correlation of age-ordered residuals after a flat-mean
detrend. This is a deliberately simple AR(1) estimator: transparent for
near-regular records and an approximation for irregular records. For
irregular paleo series, treat `rho_t` as a sensitivity parameter or
replace it with a method designed for uneven sampling. Change-point
tools such as `bcp` and `Rbeast` answer a different question: they can
help test whether a boundary or trend is independently supported, but
they are not substitutes for the lag-1 `rho_t` used in the
detection-threshold formula. A Lomb-Scargle estimator is planned for
v0.3 (`method = "lomb_scargle"`).

The Zaca record splits at 1000 yr BP. The Qinghai record splits at
15,000 yr BP, late LGM to mid-Holocene, the boundary across which many
Asian-monsoon records show a regional shift in source-water `d2H`.

``` r

rho_zaca <- estimate_temporal_autocorrelation(
  zaca$d2h_wax, zaca$age, method = "ar1"
)

dc_zaca <- detect_change(
  reconstruction    = recon_zaca,
  age               = zaca$age,
  baseline_interval = c(0, 1000),
  test_intervals    = list(post_1000 = c(1000, 2000)),
  sigma_residual    = 16,
  sigma_analytical  = 3,
  rho_t             = rho_zaca,
  beta_eff          = stats::median(slope_zaca),
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
  zaca  = list(rho_t = round(rho_zaca, 3),
                 threshold_permil = round(dc_zaca$threshold, 1),
                 intervals        = dc_zaca$intervals),
  qinghai = list(rho_t = round(rho_qh, 3),
                 threshold_permil = round(dc_qh$threshold, 1),
                 intervals        = dc_qh$intervals)
)
#> $zaca
#> $zaca$rho_t
#> [1] 0.445
#> 
#> $zaca$threshold_permil
#> [1] 58.5
#> 
#> $zaca$intervals
#>    interval n_baseline n_test delta_mean delta_median delta_lower delta_upper
#> 1 post_1000        257    127  0.1163509    0.5201522   -5.648273     6.10717
#>   p_abs_delta_gt_10 p_abs_delta_gt_30 p_abs_delta_gt_50
#> 1                 0                 0                 0
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
#> 1      lgm        162     74  -38.50674    -37.18504   -59.10398   -24.23564
#>   p_abs_delta_gt_10 p_abs_delta_gt_30 p_abs_delta_gt_50
#> 1                 1              0.82              0.13
```

The two records produce different verdicts. Zaca: lag-1 autocorrelation
0.44, 95 percent detection threshold approximately 59 per mil, posterior
probability of a 30 per mil shift across 1000 yr BP 0.00. Qinghai: lag-1
autocorrelation 0.85 (densely sampled and strongly persistent),
threshold approximately 42 per mil, posterior probability of a 30 per
mil shift across 15,000 yr BP 0.82. The Zaca record cannot distinguish a
30 per mil change in `d2H_precip` from calibration noise. The Qinghai
record provides much stronger evidence for a large LGM-to-Holocene
shift, but the 30 per mil quantitative claim remains below the 95
percent decision threshold. Two factors drive the contrast: Qinghai’s
much larger LGM-to-Holocene `d2H_wax` shift, and its high
autocorrelation, which reduces `sqrt(2(1-rho_t))` and pulls the
threshold down.

## 7. Assess a published claim

The example below asks whether each record can support an asserted Level
4 claim of a 30 per mil `d2H_precip` change. The strings supplied as
corroborating and stationarity evidence demonstrate the required API
structure; they are not a substitute for a record-specific literature
review.

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

zaca_record <- data.frame(
  d2h_wax     = zaca$d2h_wax,
  age         = zaca$age,
  d2h_wax_err = rep(3, nrow(zaca))
)
qh_record <- data.frame(
  d2h_wax     = qh$d2h_wax,
  age         = qh$age,
  d2h_wax_err = rep(3, nrow(qh))
)

verdict_zaca <- suppressWarnings(assess_claim(
  record         = zaca_record,
  claim          = build_claim(stats::median(slope_zaca),
                                rho_zaca,
                                c(0, 1000), c(1000, 2000),
                                magnitude_precip = 30),
  reconstruction = recon_zaca
))

verdict_qh <- suppressWarnings(assess_claim(
  record         = qh_record,
  claim          = build_claim(stats::median(slope_qh),
                                rho_qh,
                                c(0, 15000), c(15000, 25000),
                                magnitude_precip = 30),
  reconstruction = recon_qh
))

c(zaca_highest_level   = verdict_zaca$highest_level,
  zaca_supported_at_4  = verdict_zaca$asserted_supported,
  qinghai_highest_level  = verdict_qh$highest_level,
  qinghai_supported_at_4 = verdict_qh$asserted_supported)
#>     zaca_highest_level    zaca_supported_at_4  qinghai_highest_level 
#>                      0                      0                      2 
#> qinghai_supported_at_4 
#>                      0
```

Read each `verdict$levels` data frame top to bottom: every level above
the highest one passed is reported with the reason it failed. The Zaca
claim fails at the within-record noise step; the Qinghai claim clears
Level 2 for the asserted 30 per mil Level 4 claim. It fails Level 3
because the posterior probability for a 30 per mil `d2H_precip` shift is
below 0.95, even though the example supplies stationarity evidence for
the Level 4 controls.

## 8. Plot the reconstructions

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

plot_recon(recon_zaca, zaca$age,
           "Zaca Lake (LS14FEZA): no detection at 95%",
           boundary = 1000)
plot_recon(recon_qh, qh$age,
           "Lake Qinghai (LS16THQI01): large LGM shift",
           boundary = 15000)
```

![](paleo-record-workflow_files/figure-html/plot-1.png)

``` r


par(op)
```

Each shaded band is the 90 percent credible interval per sample,
propagating analytical uncertainty, regression-parameter uncertainty,
the local slope posterior, and the calibration’s posterior residual SD.
The dashed red line marks the interval boundary used in the
change-detection and claim-assessment examples.

## Takeaway

A record’s ability to support a `d2H_precip`-change claim depends on
three quantities evaluated for that record: its within-record `d2H_wax`
interval-mean contrast relative to `sigma_residual`, the local effective
slope, and the lag-1 temporal autocorrelation.
[`detect_change()`](https://bradleylab.github.io/leafwax/reference/detect_change.md)
packages these into a single threshold and a posterior probability;
[`assess_claim()`](https://bradleylab.github.io/leafwax/reference/assess_claim.md)
walks them through the four-level taxonomy. Records like Zaca can fail
at the initial within-record wax-change screen. Long, densely sampled
records like Qinghai can clear directional hydroclimate-change claims
and provide much stronger quantitative evidence, but the example 30 per
mil Level 4 claim still requires posterior support at the chosen
confidence level.

## Notes

- The vignette uses 100 posterior draws for speed. Production
  reconstructions should use the full posterior (omit `n_draws` and
  `n_posterior_draws`).
- The built-in
  [`estimate_temporal_autocorrelation()`](https://bradleylab.github.io/leafwax/reference/estimate_temporal_autocorrelation.md)
  is a flat-mean lag-1 estimator and assumes near-regular spacing. For
  irregular paleo series, use sensitivity analyses or a dedicated
  uneven-sampling autocorrelation method for `rho_t`. Use `bcp` or
  `Rbeast` for complementary change-point or trend checks, not as direct
  `rho_t` estimators.
