# List available models with details

Returns information about the v10 models available in the leafwax
package, including which covariates each model uses.

## Usage

``` r
list_models(check_data = TRUE, verbose = TRUE)
```

## Arguments

- check_data:

  Logical, whether to check if model data is available

- verbose:

  Logical, whether to print formatted output

## Value

Data frame with model information

## Examples

``` r
# \donttest{
# List all models
models <- list_models(verbose = FALSE)
models_head <- head(models)
# }
```
