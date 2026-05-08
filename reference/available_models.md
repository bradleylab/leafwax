# Get available models

Returns a list of all available calibration models for leaf wax hydrogen
isotope inversion. Models vary in their complexity and data
requirements.

## Usage

``` r
available_models()
```

## Value

Character vector of available model names. Models include:

- `baseline`: Basic OIPC model without spatial effects

- `baseline_sp`: Basic model with spatial Gaussian process

- `baseline_env`: Includes elevation effects

- `baseline_env_sp`: Elevation effects with spatial GP

- `baseline_veg`: Includes vegetation (PFT) effects

- `baseline_veg_sp`: Vegetation effects with spatial GP

- `c4_only_sp`: C4 vegetation effects only (spatial)

- `elevation_only_sp`: Elevation effects only (spatial)

- `elevation_c4_sp`: Combined elevation and C4 effects

- `elevation_c4_interact_sp`: With interaction terms

- `full`: All effects without spatial component

- `full_sp`: All effects with spatial component

- `full_interact`: All effects with interactions

- `full_interact_sp`: Full model with spatial GP

## Examples

``` r
# List all available models
models <- available_models()
print(models)
#>  [1] "baseline_env"             "baseline_env_sp"         
#>  [3] "baseline"                 "baseline_sp"             
#>  [5] "baseline_veg"             "baseline_veg_sp"         
#>  [7] "c4_only_sp"               "elevation_c4_interact_sp"
#>  [9] "elevation_c4_sp"          "elevation_only_sp"       
#> [11] "full_interact"            "full_interact_sp"        
#> [13] "full"                     "full_sp"                 

# Get details for a specific model
model_info <- get_model_parameters("baseline_sp")
print(model_info$description)
#> [1] "OIPC model with spatial Gaussian process"
```
