# Batch inversion for multiple samples

Convenience function to invert multiple samples with different models
and compare results.

## Usage

``` r
batch_invert_d2h(data, models = c("baseline", "baseline_sp"), ...)
```

## Arguments

- data:

  Data frame with columns matching invert_d2h arguments

- models:

  Character vector of model names to use

- ...:

  Additional arguments passed to invert_d2h

## Value

List of results from each model
