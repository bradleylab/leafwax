# Benchmark lookup table vs direct computation

Compares the speed and accuracy of lookup tables versus direct spatial
parameter computation.

## Usage

``` r
benchmark_lookup(
  model_name,
  n_locations = 100,
  lookup_table = NULL,
  verbose = TRUE
)
```

## Arguments

- model_name:

  Name of the model

- n_locations:

  Number of random test locations

- lookup_table:

  Pre-computed lookup table (NULL to create one)

- verbose:

  Logical indicating whether to print results

## Value

List with benchmark results
