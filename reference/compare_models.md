# Compare predictions across multiple models

Runs predictions using multiple models and compares results.

## Usage

``` r
compare_models(
  data,
  models = NULL,
  summary_fun = mean,
  return_all = FALSE,
  progress = TRUE,
  ...
)
```

## Arguments

- data:

  Data frame with measurements

- models:

  Character vector of model names to compare

- summary_fun:

  Function to summarize across models (default is mean)

- return_all:

  Logical whether to return all model results

- progress:

  Logical whether to show progress

- ...:

  Additional arguments passed to predict_d2h_precip

## Value

Data frame with ensemble predictions or list of all results

## Examples

``` r
if (FALSE) { # \dontrun{
data(example_data)

# Compare multiple models
comparison <- compare_models(
  example_data,
  models = c("b0b1", "b0b1_elev", "b0b1_sp")
)

# Get all individual model results
all_results <- compare_models(
  example_data,
  models = c("b0b1", "b0b1_elev"),
  return_all = TRUE
)
} # }
```
