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

- `baseline_env`: Includes precipitation-amount effects

- `baseline_env_sp`: Precipitation-amount effects with spatial GP

- `baseline_veg`: Includes vegetation interaction effects

- `baseline_veg_sp`: Vegetation interactions with spatial GP

- `c4_only_sp`: C4 vegetation effects only (spatial)

- `elevation_only_sp`: Historical elevation-context variant (spatial)

- `elevation_c4_sp`: Historical elevation-context + C4 variant

- `elevation_c4_interact_sp`: Historical elevation/C4-interaction name;
  C4 effect only

- `full`: Precipitation amount + vegetation interactions without spatial
  component

- `full_sp`: Precipitation amount + vegetation interactions with spatial
  component

- `full_interact`: Precipitation amount + vegetation interactions

- `full_interact_sp`: Full interaction model with spatial GP

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
