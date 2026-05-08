# Predict both spatial intercept and spatial slope at new locations

v10 carries two independent GPs. Both share knot coordinates and a
single length scale parameter (`ls_intercept_km == ls_slope_km` in v10's
posterior, two names for the same draw), but have distinct
`sigma_intercept_spatial` and `sigma_slope_spatial`, and distinct
`z_intercept_spatial[*]` and `z_slope_spatial[*]` knot effects.

## Usage

``` r
predict_spatial_dual_gp(coords_new, knot_coords, draws, scaling)
```

## Arguments

- coords_new:

  matrix(n_obs, 2) of (lon, lat) in DEGREES.

- knot_coords:

  matrix(n_knots, 2) of (lon, lat) in DEGREES.

- draws:

  data.frame of posterior draws (subset of leafwax_posterior\$draws).
  Must contain columns `z_intercept_spatial[1..n_knots]`,
  `z_slope_spatial[1..n_knots]`, `sigma_intercept_spatial`,
  `sigma_slope_spatial`, and one of `ls_intercept_km` / `ls_slope_km`.

- scaling:

  list with `lon_mean`, `lon_sd`, `lat_mean`, `lat_sd`.

## Value

list with two matrices, each n_draws x n_obs: `intercept` (additive
contribution to beta_0 in standardized d2H_wax space) and `slope`
(additive contribution to beta_oipc).
