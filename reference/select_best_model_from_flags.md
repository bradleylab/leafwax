# Select best model based on available data

Automatically selects the most appropriate v10 model name from the 14
shipped variants given which covariates the user has available.
Spatial-aware models are preferred when `prefer_spatial = TRUE`.

## Usage

``` r
select_best_model_from_flags(
  has_elevation = FALSE,
  has_c4 = FALSE,
  has_pft = FALSE,
  prefer_spatial = TRUE,
  verbose = FALSE
)
```

## Arguments

- has_elevation:

  Logical, whether elevation data is available

- has_c4:

  Logical, whether C4 vegetation data is available

- has_pft:

  Logical, whether PFT data is available

- prefer_spatial:

  Logical, whether to prefer spatial models

- verbose:

  Logical, whether to print selection reasoning

## Value

Character string with selected v10 model name
