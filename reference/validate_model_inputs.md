# Validate inputs for a specific model

Checks that all required predictors are provided and warns about unused
ones.

## Usage

``` r
validate_model_inputs(
  model_name,
  d2h_wax,
  longitude,
  latitude,
  elevation = NULL,
  c4_percent = NULL,
  pft_tree = NULL,
  pft_shrub = NULL,
  pft_grass = NULL,
  verbose = TRUE
)
```

## Arguments

- model_name:

  Name of the model

- d2h_wax:

  Leaf wax d2H values

- longitude:

  Longitude values

- latitude:

  Latitude values

- elevation:

  Elevation values (optional)

- c4_percent:

  C4 percentage values (optional)

- pft_tree:

  Tree PFT fraction (optional)

- pft_shrub:

  Shrub PFT fraction (optional)

- pft_grass:

  Grass PFT fraction (optional)

- verbose:

  Whether to print validation messages

## Value

List with validation results
