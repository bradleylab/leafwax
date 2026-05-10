# List available models with details

Returns information about the v10 models available in the leafwax
package, including which covariates each model uses.

## Usage

``` r
list_models(check_data = TRUE, verbose = TRUE)
```

## Arguments

- check_data:

  Logical, whether to check if model data is available

- verbose:

  Logical, whether to print formatted output

## Value

Data frame with model information

## Examples

``` r
# \donttest{
# List all models
models <- list_models()
#> === Available Models in leafwax ===
#> 
#> Non-spatial models:
#>   baseline                  Basic OIPC model without spatial or environmental effects
#>                             Status: In package
#> 
#>   baseline_env              OIPC + precipitation-amount effect
#>                             Status: In package
#> 
#>   baseline_veg              OIPC + vegetation interaction effects (C4/PFT)
#>                             Requires: C4 fraction, PFT fractions
#>                             Status: In package
#> 
#>   full                      Precipitation amount + vegetation interactions
#>                             Requires: C4 fraction, PFT fractions
#>                             Status: In package
#> 
#>   full_interact             Precipitation amount + vegetation interactions (no spatial GP)
#>                             Requires: C4 fraction, PFT fractions
#>                             Status: In package
#> 
#> 
#> Spatial models (with Gaussian process):
#>   baseline_sp               Basic OIPC model with spatial Gaussian process
#>                             Status: In package
#> 
#>   baseline_env_sp           OIPC + precipitation-amount + spatial effects
#>                             Status: In package
#> 
#>   baseline_veg_sp           OIPC + vegetation interactions + spatial effects
#>                             Requires: C4 fraction, PFT fractions
#>                             Status: In package
#> 
#>   c4_only_sp                OIPC + C4 fraction + spatial effects
#>                             Requires: C4 fraction
#>                             Status: In package
#> 
#>   elevation_only_sp         OIPC + spatial effects (historical elevation-context variant; no fitted elevation coefficient)
#>                             Status: In package
#> 
#>   elevation_c4_sp           OIPC + C4 + spatial effects (historical elevation-context variant)
#>                             Requires: C4 fraction
#>                             Status: In package
#> 
#>   elevation_c4_interact_sp  OIPC + C4 + spatial effects (historical elevation/interaction-context variant; no fitted elevation or interaction coefficient)
#>                             Requires: C4 fraction
#>                             Status: In package
#> 
#>   full_sp                   Precipitation amount + vegetation interactions + spatial GP
#>                             Requires: C4 fraction, PFT fractions
#>                             Status: In package
#> 
#>   full_interact_sp          Precipitation amount + vegetation interactions + spatial GP
#>                             Requires: C4 fraction, PFT fractions
#>                             Status: In package
#> 
#> Total models: 14 
#> Models with data: 14 of 14 
head(models)
#>             model                                               description
#> 1        baseline Basic OIPC model without spatial or environmental effects
#> 2     baseline_sp            Basic OIPC model with spatial Gaussian process
#> 3    baseline_env                        OIPC + precipitation-amount effect
#> 4 baseline_env_sp             OIPC + precipitation-amount + spatial effects
#> 5    baseline_veg            OIPC + vegetation interaction effects (C4/PFT)
#> 6 baseline_veg_sp          OIPC + vegetation interactions + spatial effects
#>   has_elevation has_precip has_c4 has_pft has_spatial size_mb
#> 1         FALSE      FALSE  FALSE   FALSE       FALSE     581
#> 2         FALSE      FALSE  FALSE   FALSE        TRUE     917
#> 3         FALSE       TRUE  FALSE   FALSE       FALSE     639
#> 4         FALSE       TRUE  FALSE   FALSE        TRUE     992
#> 5         FALSE      FALSE   TRUE    TRUE       FALSE     717
#> 6         FALSE      FALSE   TRUE    TRUE        TRUE    1200
#>                     requires data_package data_cached data_status
#> 1                       none         TRUE       FALSE  In package
#> 2                       none         TRUE       FALSE  In package
#> 3                       none         TRUE       FALSE  In package
#> 4                       none         TRUE       FALSE  In package
#> 5 C4 fraction, PFT fractions         TRUE       FALSE  In package
#> 6 C4 fraction, PFT fractions         TRUE       FALSE  In package
# }
```
