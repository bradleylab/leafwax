# Paleo-record workflow: from a downcore series to a defensible claim

This vignette walks the v0.2.0 paleo-record workflow on a real Iso2k
record, Lake Malawi (LS11KOMA, Konecky et al.). The chain is:

1.  Load the downcore series.
2.  Estimate the within-record residual SD (`sigma_within`).
3.  Extract or override the local effective slope.
4.  Run the inversion with `record_id`, `sigma_within`, and `slope`.
5.  Compute a within-record detection threshold and the posterior
    probability of a hypothesised change.
6.  Assess a published claim against the four-level taxonomy from
    manuscript Section 4.5.6.
7.  Plot the reconstructed `d2H_precip` series with within-record
    uncertainty.

Lake Malawi was chosen because its within-record variability is small
(~3 per mil over the Common Era), which makes it a useful educational
example: most claimed shifts at this site will not survive Level 1.

## 1. Load the downcore series

``` r

library(leafwax)

malawi_path <- system.file(
  "extdata", "example_records", "LS11KOMA_d2H.csv",
  package = "leafwax"
)
malawi <- read.csv(malawi_path)
malawi$d2h_wax <- malawi$d2H_wax
malawi$age     <- malawi$age_yrBP
malawi
#>    age_yrBP  d2H_wax  d2h_wax  age
#> 1        96 -102.962 -102.962   96
#> 2       258 -101.987 -101.987  258
#> 3       406 -105.778 -105.778  406
#> 4       662 -107.577 -107.577  662
#> 5       899 -104.848 -104.848  899
#> 6       905 -106.813 -106.813  905
#> 7      1173 -107.227 -107.227 1173
#> 8      1315 -112.561 -112.561 1315
#> 9      1546 -109.132 -109.132 1546
#> 10     1758 -112.071 -112.071 1758
#> 11     1974 -105.353 -105.353 1974
```

The record has 11 samples spanning the Common Era (~100–2000 yrBP) at
Lake Malawi (10.02 deg S, 34.19 deg E).

## 2. Estimate sigma_within

[`estimate_sigma_within()`](https://bradleylab.github.io/leafwax/reference/estimate_sigma_within.md)
computes the within-record residual SD on a stationarity-defended
baseline interval. Manuscript Section 4.5.3 explains why the global
posterior `sigma` (~16 per mil) overstates the relevant noise for change
detection inside a single record.

For Lake Malawi, the full Common-Era record is reasonably stationary and
we treat the entire 11-sample series as the baseline. The function will
warn that this conflates real climate variability with noise – accepted
here for illustration; a real application should defend a sub-interval
on independent grounds.

``` r

sw <- suppressWarnings(estimate_sigma_within(
  d2h_wax       = malawi$d2h_wax,
  age           = malawi$age,
  baseline_interval = NULL,   # full record (warning)
  detrend       = "linear",
  ar1_correction = TRUE
))
sw
#> $sigma_within
#> [1] 2.439809
#> 
#> $sigma_within_se
#> [1] 0.5455578
#> 
#> $sigma_naive
#> [1] 2.552037
#> 
#> $n_baseline
#> [1] 11
#> 
#> $rho_t_baseline
#> [1] -0.2932885
#> 
#> $method
#> [1] "baseline_interval=full record (WARNING); detrend=linear; ar1_correction=TRUE"
```

A within-record SD of ~3 per mil after linear detrending is
characteristic of Common-Era leaf-wax records.

## 3. Local effective slope

[`local_effective_slope()`](https://bradleylab.github.io/leafwax/reference/local_effective_slope.md)
returns a per-draw vector of the d2H_wax-d2H_precip slope at the site,
combining the global posterior beta_oipc with the spatial slope GP. The
default ceiling is 0.88, the simple-model upper bound from manuscript
Section 4.5.5.

``` r

malawi_lon <- 34.1878
malawi_lat <- -10.0183

slope_post <- suppressWarnings(local_effective_slope(
  longitude   = malawi_lon,
  latitude    = malawi_lat,
  model_name  = "baseline_sp",
  n_draws     = 200,
  ceiling     = 0.88,
  verbose     = FALSE
))

quantile(slope_post, c(0.025, 0.5, 0.975))
#>      2.5%       50%     97.5% 
#> 0.4632060 0.5776181 0.7080186
```

A defended slope point estimate would typically be the posterior median;
here we keep the per-draw vector so the inversion propagates slope
uncertainty.

## 4. Bayesian inversion with sigma_within and slope

[`invert_d2H()`](https://bradleylab.github.io/leafwax/reference/invert_d2h.md)
accepts the slope vector built above plus the within- record SD. We pass
`record_id` so the function validates that all rows are from one site,
and we ask for the full posterior draws matrix so we can hand it to
[`detect_change()`](https://bradleylab.github.io/leafwax/reference/detect_change.md).

``` r

recon <- suppressWarnings(invert_d2H(
  d2H_wax    = malawi$d2h_wax,
  d2H_wax_sd = rep(3, nrow(malawi)),
  longitude  = rep(malawi_lon, nrow(malawi)),
  latitude   = rep(malawi_lat, nrow(malawi)),
  model_name = "baseline_sp",
  n_posterior_draws = 200,
  sigma_within = sw$sigma_within,
  slope        = slope_post,
  record_id    = "LS11KOMA",
  return_full  = TRUE,
  verbose      = FALSE
))

head(recon$summary[, c("d2h_wax", "d2h_precip_median",
                       "d2h_precip_lower", "d2h_precip_upper")])
#>    d2h_wax d2h_precip_median d2h_precip_lower d2h_precip_upper
#> 1 -102.962          62.61846         29.98491        105.05846
#> 2 -101.987          65.23026         28.40409        102.54416
#> 3 -105.778          57.76140         25.52705         95.84459
#> 4 -107.577          55.47606         19.82396         86.73767
#> 5 -104.848          58.98257         26.62906         95.63846
#> 6 -106.813          55.44942         25.66746         94.91055
```

The returned `summary` has one row per sample with the posterior median
and credible-interval bounds; `posterior_draws` is the n_iter x
n_samples matrix used below.

## 5. Detection threshold and posterior probability of change

[`detect_change()`](https://bradleylab.github.io/leafwax/reference/detect_change.md)
reports the manuscript Section 4.5.3 detection threshold and the
posterior probability that the difference in mean d2H_precip between two
intervals exceeds a magnitude. We split the record at 1000 yrBP and ask
whether there was a 30 per mil shift in d2H_precip across the boundary.

``` r

rho_t <- estimate_temporal_autocorrelation(
  malawi$d2h_wax, malawi$age, method = "ar1"
)

dc <- detect_change(
  reconstruction    = recon,
  age               = malawi$age,
  baseline_interval = c(0, 1000),
  test_intervals    = list(post_1000 = c(1000, 2000)),
  sigma_within      = sw$sigma_within,
  sigma_analytical  = 3,
  rho_t             = rho_t,
  beta_eff          = stats::median(slope_post),
  confidence        = 0.95,
  magnitudes        = c(10, 30, 50)
)

dc$threshold
#> [1] 14.4393
dc$intervals
#>    interval n_baseline n_test delta_mean delta_median delta_lower delta_upper
#> 1 post_1000          6      5  -7.626347    -7.690567   -14.66225  -0.7655204
#>   p_abs_delta_gt_10 p_abs_delta_gt_30 p_abs_delta_gt_50
#> 1              0.29                 0                 0
```

The threshold is the smallest d2H_precip change between two independent
samples at this site that can be distinguished from within-record noise
at 95% confidence. With sigma_within ~3 per mil the threshold is
comparatively small; the actual record’s posterior delta is typically
smaller still, which is the point of the example.

## 6. Assess a published claim

[`assess_claim()`](https://bradleylab.github.io/leafwax/reference/assess_claim.md)
walks the four-level taxonomy from manuscript Section 4.5.6. We test a
hypothetical claim that this record shows a 30 per mil drying signal
across 1000 yrBP, supported by some corroborating evidence and
stationarity arguments.

``` r

malawi_record <- data.frame(
  d2h_wax     = malawi$d2h_wax,
  age         = malawi$age,
  d2h_wax_err = rep(3, nrow(malawi))
)

claim <- list(
  level             = 4,                       # asserted level
  interval_baseline = c(0, 1000),
  interval_test     = c(1000, 2000),
  sigma_within      = sw$sigma_within,
  sigma_analytical  = 3,
  rho_t             = rho_t,
  confidence        = 0.95,
  beta_eff          = stats::median(slope_post),
  magnitude_precip  = 30,
  corroborating_proxies = list(
    speleothem_d18O = "regional speleothems show coeval shift"
  ),
  vegetation_stationary = list(
    value    = TRUE,
    evidence = "n-alkane chain length distributions stable across the boundary"
  ),
  seasonal_source_stationary = list(
    value    = TRUE,
    evidence = "regional speleothem d18O shows no seasonality shift"
  ),
  evapotranspirative_stationary = list(
    value    = TRUE,
    evidence = "leaf-water proxy stable; no aridity transition"
  )
)

verdict <- suppressWarnings(assess_claim(
  record         = malawi_record,
  claim          = claim,
  reconstruction = recon
))

verdict$highest_level
#> [1] 0
verdict$asserted_supported
#> [1] FALSE
verdict$levels
#>   level passed                                                      summary
#> 1     1  FALSE delta_wax = -4.27 permil; 95% threshold = 8.34 permil (FAIL)
#> 2     2  FALSE                                   blocked by Level 1 failure
#> 3     3  FALSE                                   blocked by Level 2 failure
#> 4     4  FALSE                                   blocked by Level 3 failure
```

The taxonomy walks each level in turn: every level above the highest one
passed is reported with the reason it failed. Reading the `levels` data
frame top to bottom is the recommended way to see what a record-claim
pair supports.

## 7. Plot the reconstructed d2H_precip with within-record uncertainty

``` r

op <- par(mar = c(4, 4, 1, 1))

ord <- order(malawi$age)
plot(
  malawi$age[ord],
  recon$summary$d2h_precip_median[ord],
  type = "o", pch = 16, col = "black",
  xlim = rev(range(malawi$age)),
  ylim = range(c(recon$summary$d2h_precip_lower,
                 recon$summary$d2h_precip_upper)),
  xlab = "Age (yr BP)",
  ylab = "d2H_precip (per mil)"
)
polygon(
  c(malawi$age[ord], rev(malawi$age[ord])),
  c(recon$summary$d2h_precip_lower[ord],
    rev(recon$summary$d2h_precip_upper[ord])),
  border = NA, col = adjustcolor("steelblue", alpha.f = 0.3)
)
```

![](paleo-record-workflow_files/figure-html/plot-1.png)

``` r

par(op)
```

The shaded band is the 90% credible interval per sample, propagating
analytical uncertainty, regression-parameter uncertainty, the local
slope posterior, and the within-record residual SD.

## Notes

- This vignette uses 200 posterior draws for speed. Production
  reconstructions should use the full posterior (omit `n_draws` and
  `n_posterior_draws`).
- Re-running the workflow on a longer record (e.g., LS16THN301, an 8 kyr
  Holocene series with ~35 per mil within-record SD) returns a much
  larger detection threshold and reaches Level 3+ for the larger claimed
  shifts that record was published with. The workflow is identical; only
  the inputs change.
