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
#>   baseline_env              OIPC + elevation effects
#>                             Requires: elevation
#>                             Status: In package
#> 
#>   baseline_veg              OIPC + vegetation effects (C4/C3)
#>                             Requires: C4 fraction, PFT fractions
#>                             Status: In package
#> 
#>   full                      Full model with elevation + vegetation effects
#>                             Requires: elevation, C4 fraction, PFT fractions
#>                             Status: In package
#> 
#>   full_interact             Full model with interactions (no spatial)
#>                             Requires: elevation, C4 fraction, PFT fractions
#>                             Status: In package
#> 
#> 
#> Spatial models (with Gaussian process):
#>   baseline_sp               Basic OIPC model with spatial Gaussian process
#>                             Status: In package
#> 
#>   baseline_env_sp           OIPC + elevation + spatial effects
#>                             Requires: elevation
#>                             Status: In package
#> 
#>   baseline_veg_sp           OIPC + vegetation + spatial effects
#>                             Requires: C4 fraction, PFT fractions
#>                             Status: In package
#> 
#>   c4_only_sp                OIPC + C4 fraction + spatial effects
#>                             Requires: C4 fraction
#>                             Status: In package
#> 
#>   elevation_only_sp         OIPC + elevation + spatial effects
#>                             Requires: elevation
#>                             Status: In package
#> 
#>   elevation_c4_sp           OIPC + elevation + C4 + spatial effects
#>                             Requires: elevation, C4 fraction
#>                             Status: In package
#> 
#>   elevation_c4_interact_sp  OIPC + elevation x C4 interaction + spatial effects
#>                             Requires: elevation, C4 fraction
#>                             Status: In package
#> 
#>   full_sp                   Full model with all effects + spatial GP
#>                             Requires: elevation, C4 fraction, PFT fractions
#>                             Status: In package
#> 
#>   full_interact_sp          Full model with all interactions + spatial GP
#>                             Requires: elevation, C4 fraction, PFT fractions
#>                             Status: In package
#> 
#> Total models: 14 
#> Models with data: 14 of 14 
head(models)
#>             model                                               description
#> 1        baseline Basic OIPC model without spatial or environmental effects
#> 2     baseline_sp            Basic OIPC model with spatial Gaussian process
#> 3    baseline_env                                  OIPC + elevation effects
#> 4 baseline_env_sp                        OIPC + elevation + spatial effects
#> 5    baseline_veg                         OIPC + vegetation effects (C4/C3)
#> 6 baseline_veg_sp                       OIPC + vegetation + spatial effects
#>   has_elevation has_c4 has_pft has_spatial size_mb                   requires
#> 1         FALSE  FALSE   FALSE       FALSE     581                       none
#> 2         FALSE  FALSE   FALSE        TRUE     917                       none
#> 3          TRUE  FALSE   FALSE       FALSE     639                  elevation
#> 4          TRUE  FALSE   FALSE        TRUE     992                  elevation
#> 5         FALSE   TRUE    TRUE       FALSE     717 C4 fraction, PFT fractions
#> 6         FALSE   TRUE    TRUE        TRUE    1200 C4 fraction, PFT fractions
#>   data_package data_cached data_status
#> 1         TRUE       FALSE  In package
#> 2         TRUE       FALSE  In package
#> 3         TRUE       FALSE  In package
#> 4         TRUE       FALSE  In package
#> 5         TRUE       FALSE  In package
#> 6         TRUE       FALSE  In package
# }
```
