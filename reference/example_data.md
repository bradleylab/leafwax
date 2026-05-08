# Example leaf wax hydrogen isotope data

A 10-row data frame of synthetic leaf wax hydrogen isotope measurements
bundled for demonstration and testing.

## Usage

``` r
example_data
```

## Format

A data frame with 10 rows and 10 variables:

- site_id:

  Character, site identifier

- longitude:

  Numeric, longitude in decimal degrees (-180 to 180)

- latitude:

  Numeric, latitude in decimal degrees (-90 to 90)

- elevation:

  Numeric, elevation in meters above sea level

- d2h_wax:

  Numeric, leaf wax hydrogen isotope value in per mil VSMOW

- d2h_wax_sd:

  Numeric, analytical uncertainty in per mil

- c4_fraction:

  Numeric, C4 vegetation fraction (0-1)

- pft_tree:

  Numeric, tree plant functional type fraction (0-1)

- pft_shrub:

  Numeric, shrub plant functional type fraction (0-1)

- pft_grass:

  Numeric, grass plant functional type fraction (0-1)

## Source

Synthetic values designed to span the calibration range.

## Examples

``` r
data(example_data)
head(example_data)
#>   site_id longitude latitude elevation d2h_wax d2h_wax_sd c4_fraction pft_tree
#> 1  SITE_1    -120.5     45.2      1200    -145          3        0.10      0.7
#> 2  SITE_2    -115.2     42.8      1500    -138          3        0.20      0.6
#> 3  SITE_3    -110.8     40.1       800    -152          3        0.15      0.5
#> 4  SITE_4    -105.3     38.5      1000    -130          3        0.30      0.4
#> 5  SITE_5    -100.1     36.2       500    -125          3        0.40      0.3
#> 6  SITE_6     -95.7     34.8       300    -118          3        0.50      0.2
#>   pft_shrub pft_grass
#> 1       0.2       0.1
#> 2       0.3       0.1
#> 3       0.3       0.2
#> 4       0.3       0.3
#> 5       0.3       0.4
#> 6       0.3       0.5
```
