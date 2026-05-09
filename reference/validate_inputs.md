# Validate input data for inversion

Checks that input data meets requirements for the specified model and
returns cleaned, validated data.

## Usage

``` r
validate_inputs(
  d2h_wax,
  longitude,
  latitude,
  d2h_wax_err = NULL,
  elevation = NULL,
  c4_fraction = NULL,
  pft_tree = NULL,
  pft_shrub = NULL,
  pft_grass = NULL,
  model_name = "baseline"
)
```

## Arguments

- d2h_wax:

  Leaf wax d2H values

- longitude:

  Longitude values

- latitude:

  Latitude values

- d2h_wax_err:

  Measurement uncertainties

- elevation:

  Elevation values

- c4_fraction:

  C4 vegetation fraction

- pft_tree:

  Tree PFT fraction

- pft_shrub:

  Shrub PFT fraction

- pft_grass:

  Grass PFT fraction

- model_name:

  Name of model to use

## Value

List of validated inputs
