# Batch predict precipitation d2H for multiple sites

Processes multiple sites with progress indicators and optional
parallelization. Handles large datasets efficiently by processing in
chunks.

## Usage

``` r
batch_predict(
  data,
  model = "auto",
  chunk_size = 100,
  parallel = FALSE,
  n_cores = NULL,
  progress = TRUE,
  return_diagnostics = FALSE,
  ...
)
```

## Arguments

- data:

  Data frame containing all measurements

- model:

  Model name or "auto" for automatic selection

- chunk_size:

  Number of sites to process at once (default 100)

- parallel:

  Logical whether to use parallel processing

- n_cores:

  Number of cores for parallel processing (NULL for auto)

- progress:

  Logical whether to show progress bar

- return_diagnostics:

  Logical whether to return diagnostic information

- ...:

  Additional arguments passed to predict_d2h_precip

## Value

Data frame with predictions for all sites

## Examples

``` r
if (FALSE) { # \dontrun{
# Load a large dataset
large_data <- read.csv("sites.csv")

# Process with progress bar
results <- batch_predict(large_data, progress = TRUE)

# Process in parallel
results <- batch_predict(large_data, parallel = TRUE, n_cores = 4)

# Process with specific model
results <- batch_predict(large_data, model = "baseline_env_sp")
} # }
```
