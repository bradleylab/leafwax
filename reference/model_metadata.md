# Model metadata for the v10 calibration models

A list summarizing the 14 hierarchical Bayesian calibration models
shipped with the package. Field names match the v10 model variants
described in the manuscript.

## Usage

``` r
model_metadata
```

## Format

A named list. Each element is itself a list with fields describing one
model: `name`, `description`, `has_spatial`, `has_elevation`, `has_c4`,
`has_vegetation`, and `size_mb`. See
[`get_all_model_metadata`](https://bradleylab.github.io/leafwax/reference/get_all_model_metadata.md)
for the canonical accessor.

## Source

Generated from the v10 hierarchical Bayesian calibration run.

## Examples

``` r
data(model_metadata)
names(model_metadata)
#>  [1] "b0b1"                "b0b1_elev"           "b0b1_c4"            
#>  [4] "b0b1_pft"            "b0b1_sp"             "b0b1_elev_sp"       
#>  [7] "b0b1_c4_sp"          "b0b1_pft_sp"         "b0b1_elev_c4"       
#> [10] "b0b1_elev_pft"       "b0b1_c4_pft"         "b0b1_elev_c4_sp"    
#> [13] "b0b1_elev_pft_sp"    "b0b1_elev_c4_pft_sp"
```
