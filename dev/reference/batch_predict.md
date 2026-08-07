# Jointly invert multiple observations from one record

Sends all rows through one joint Bayesian inversion so they coherently
reweight the shared calibration draws. Chunked and parallel processing
are deliberately disabled because splitting a record changes that joint
target.

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

  Data frame containing observations from one same-site record. A
  `record_id` column is required when there is more than one row.

- model:

  Model name or "auto" for automatic selection

- chunk_size:

  Retained for compatibility and recorded in diagnostics; it does not
  split the joint inversion.

- parallel:

  Must be `FALSE`; parallel chunks would change the target.

- n_cores:

  Retained for compatibility and diagnostics.

- progress:

  Logical whether to show progress bar

- return_diagnostics:

  Logical whether to return diagnostic information

- ...:

  Additional arguments passed to predict_d2h_precip

## Value

A `leafwax_inverse` object for the jointly inverted rows.

## Examples

``` r
if (FALSE) { # \dontrun{
local({
  old <- options(leafwax.suppress_preview_warning = TRUE)
  on.exit(options(old))

  data(example_data)
  prior <- d2h_prior_normal(mean = -70, sd = 30)
  large_data <- example_data[rep(seq_len(nrow(example_data)), length.out = 12), ]
  row.names(large_data) <- NULL
  large_data$longitude <- large_data$longitude[[1]]
  large_data$latitude <- large_data$latitude[[1]]
  large_data$record_id <- "example_record"

  # Process in chunks
  results <- batch_predict(
    large_data,
    chunk_size = 6,
    progress = FALSE,
    prior = prior,
    verbose = FALSE
  )

  # Process with a specific model
  results <- batch_predict(
    large_data,
    model = "baseline_sp",
    chunk_size = 6,
    progress = FALSE,
    prior = prior,
    verbose = FALSE
  )
})
} # }
```
