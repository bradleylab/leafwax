# Ensemble predictions across multiple models

Ensemble predictions across multiple models

## Usage

``` r
invert_d2H_ensemble(
  ...,
  models = c("b0b1_elev_c4_pft_sp", "b0b1_elev_c4_sp", "b0b1_elev_pft_sp"),
  ensemble_method = c("equal", "all")
)
```

## Arguments

- ...:

  Arguments passed to
  [`invert_d2H`](https://bradleylab.github.io/leafwax/reference/invert_d2h.md)

- models:

  Character vector of model names to include in ensemble

- ensemble_method:

  Method for combining models: "equal" or "all"

## Value

List with ensemble predictions and individual model results
