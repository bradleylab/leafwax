# Get leafwax configuration

Returns current configuration options for the leafwax package.

## Usage

``` r
leafwax_config(option = NULL)
```

## Arguments

- option:

  Specific option to retrieve (NULL for all)

## Value

List of options or single option value

## Examples

``` r
# Get all configuration options
cfg <- leafwax_config()

# Get specific option
auto_download <- leafwax_config("auto_download")
```
