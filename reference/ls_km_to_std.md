# Convert ls in km to standardized-coordinate units, matching the v10 Stan model's `coord_scale_km = mean(coord_scaling) * 111.0` formula.

Convert ls in km to standardized-coordinate units, matching the v10 Stan
model's `coord_scale_km = mean(coord_scaling) * 111.0` formula.

## Usage

``` r
ls_km_to_std(ls_km, scaling)
```

## Arguments

- ls_km:

  numeric in km

- scaling:

  list with \$lon_sd and \$lat_sd (degrees)
