# Predict precipitation d2H from leaf wax d2H

Main user-facing function for inverting leaf wax hydrogen isotopes to
precipitation isotopes. Automatically selects appropriate model based on
available data and returns results in a tidy format.

## Usage

``` r
predict_d2h_precip(
  data = NULL,
  d2h_wax = NULL,
  longitude = NULL,
  latitude = NULL,
  d2h_wax_err = NULL,
  elevation = NULL,
  c4_fraction = NULL,
  pft_tree = NULL,
  pft_shrub = NULL,
  pft_grass = NULL,
  model = "auto",
  n_draws = NULL,
  use_lookup = TRUE,
  credible_level = 0.9,
  return_draws = FALSE,
  progress = TRUE,
  verbose = TRUE
)
```

## Arguments

- data:

  Data frame containing measurements, or NULL to use individual vectors

- d2h_wax:

  Numeric vector of leaf wax d2H values (per mil)

- longitude:

  Numeric vector of longitudes (decimal degrees)

- latitude:

  Numeric vector of latitudes (decimal degrees)

- d2h_wax_err:

  Numeric vector of measurement uncertainties (optional)

- elevation:

  Numeric vector of elevations in meters (optional)

- c4_fraction:

  Numeric vector of C4 vegetation fraction 0-1 (optional)

- pft_tree:

  Numeric vector of tree PFT fraction (optional)

- pft_shrub:

  Numeric vector of shrub PFT fraction (optional)

- pft_grass:

  Numeric vector of grass PFT fraction (optional)

- model:

  Character string specifying model, or "auto" for automatic selection

- n_draws:

  Integer number of posterior draws (NULL for all)

- use_lookup:

  Logical whether to use lookup tables for spatial models

- credible_level:

  Numeric credible interval level (default 0.9)

- return_draws:

  Logical whether to return full posterior draws

- progress:

  Logical whether to show progress bar for batch processing

- verbose:

  Logical whether to print status messages

## Value

A data frame with predictions (or list if return_draws = TRUE):

- d2h_precip_mean:

  Mean predicted precipitation d2H

- d2h_precip_median:

  Median predicted precipitation d2H

- d2h_precip_sd:

  Standard deviation of predictions

- d2h_precip_lower:

  Lower credible interval bound

- d2h_precip_upper:

  Upper credible interval bound

- model_used:

  Name of model used for prediction

## Examples

``` r
if (FALSE) { # \dontrun{
# Using data frame input
data(example_data)
results <- predict_d2h_precip(example_data)

# Using individual vectors
results <- predict_d2h_precip(
  d2h_wax = c(-150, -140, -130),
  longitude = c(-120, -110, -100),
  latitude = c(40, 35, 30),
  elevation = c(1000, 1500, 500)
)

# Specify model explicitly
results <- predict_d2h_precip(
  example_data,
  model = "b0b1_elev_sp"
)

# Get full posterior draws
results <- predict_d2h_precip(
  example_data,
  return_draws = TRUE
)
} # }
```
