# Set leafwax configuration

Sets configuration options for the leafwax package.

## Usage

``` r
leafwax_set_config(..., persist = TRUE)
```

## Arguments

- ...:

  Named arguments for options to set

- persist:

  Logical, whether to show code to make changes permanent

## Value

Invisible NULL

## Examples

``` r
if (FALSE) { # \dontrun{
# Enable auto-download
leafwax_set_config(auto_download = TRUE)

# Set multiple options
leafwax_set_config(
  auto_download = TRUE,
  cache_dir = "~/my_leafwax_cache",
  verbose = FALSE
)
} # }
```
