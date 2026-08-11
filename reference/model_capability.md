# Fitted capabilities for a model, from the config-derived manifest

Fitted capabilities for a model, from the config-derived manifest

## Usage

``` r
model_capability(model_name)
```

## Arguments

- model_name:

  Character model name (e.g. "full_sp"). A trailing "\_rfoff"
  (range_factor-off sensitivity variant) is resolved to its base.

## Value

Named list of capability flags plus n_pp_knots.
