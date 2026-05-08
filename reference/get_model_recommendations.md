# Get model recommendations based on available data

Suggests the best model(s) to use given the available predictors.

## Usage

``` r
get_model_recommendations(
  has_elevation = FALSE,
  has_c4 = FALSE,
  has_pft = FALSE,
  prefer_spatial = TRUE,
  available_models = NULL
)
```

## Arguments

- has_elevation:

  Whether elevation data is available

- has_c4:

  Whether C4 vegetation data is available

- has_pft:

  Whether PFT data is available

- prefer_spatial:

  Whether to prefer spatial models

- available_models:

  Vector of available model names (optional)

## Value

Ranked list of recommended models
