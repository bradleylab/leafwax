# Load posterior draws for a model

Loads posterior draws directly from package data - no downloads needed!

## Usage

``` r
load_posteriors(model_name, n_draws = NULL, verbose = TRUE)
```

## Arguments

- model_name:

  Character string specifying the model name

- n_draws:

  Integer number of posterior draws to use (NULL for all)

- verbose:

  Logical indicating whether to print loading information

## Value

A list containing model draws and metadata

## Examples

``` r
# Load a model
model <- load_posteriors("baseline")
#> Loading model: baseline 
#>   Loaded 1000 draws, 17 parameters
#>   Loaded standardization parameters (20 fields)

# Load with limited draws
model_fast <- load_posteriors("baseline_sp", n_draws = 1000)
#> Loading model: baseline_sp 
#>   Loaded 1000 draws, 271 parameters
#>   Loaded 125 spatial knots
#>   Loaded standardization parameters (20 fields)
```
