# Generate global 1x1 degree grid

Creates a regular grid of longitude and latitude coordinates at 1-degree
resolution covering the entire globe.

## Usage

``` r
generate_global_grid(
  lon_min = -180,
  lon_max = 180,
  lat_min = -90,
  lat_max = 90,
  resolution = 1
)
```

## Arguments

- lon_min:

  Minimum longitude (default -180)

- lon_max:

  Maximum longitude (default 180)

- lat_min:

  Minimum latitude (default -90)

- lat_max:

  Maximum latitude (default 90)

- resolution:

  Grid resolution in degrees (default 1)

## Value

Data frame with columns lon, lat, cell_id

## Examples

``` r
if (FALSE) { # \dontrun{
grid <- generate_global_grid()
head(grid)
} # }
```
