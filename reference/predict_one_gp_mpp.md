# Predict an mPP Gaussian-process random effect at a new location

Single-GP version. Used internally by
[`predict_spatial_dual_gp()`](https://bradleylab.github.io/leafwax/reference/predict_spatial_dual_gp.md)
for each of the two (intercept, slope) fields. Matches the Matern 3/2
kernel and standardized-coordinate convention from the v10 Stan model.

## Usage

``` r
predict_one_gp_mpp(
  coords_new,
  knot_coords,
  z_knots,
  sigma_draws,
  ls_km_draws,
  scaling,
  jitter = 1e-04
)
```

## Arguments

- coords_new:

  matrix(n_obs, 2) of (lon, lat) in DEGREES.

- knot_coords:

  matrix(n_knots, 2) of (lon, lat) in DEGREES.

- z_knots:

  matrix(n_draws, n_knots) of standardized knot effects (e.g.
  `z_intercept_spatial[1..125]` from the posterior).

- sigma_draws:

  numeric(n_draws), the GP marginal SD.

- ls_km_draws:

  numeric(n_draws), the GP length scale in km (e.g. `ls_intercept_km`).

- scaling:

  list with `lon_mean`, `lon_sd`, `lat_mean`, `lat_sd`.

- jitter:

  ridge added to K_knots for numerical stability.

## Value

matrix(n_draws, n_obs) of predicted GP values at the new sites.
