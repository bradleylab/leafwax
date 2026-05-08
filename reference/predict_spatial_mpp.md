# Legacy single-GP predictor – DEPRECATED.

Retained as a stub that calls `predict_one_gp_mpp` with a corrected
Matern 3/2 kernel. The original implementation used an exponential
kernel, did not standardize coordinates, and was incompatible with v10
fits. New code should use
[`predict_spatial_dual_gp()`](https://bradleylab.github.io/leafwax/reference/predict_spatial_dual_gp.md).

## Usage

``` r
predict_spatial_mpp(
  coords_std,
  knot_coords,
  z_spatial_draws,
  ls_gp_draws,
  sigma_gp_draws
)
```

## Arguments

- coords_std:

  numeric, already-standardized (lon, lat) of the prediction site.
  Treated as a length-2 vector.

- knot_coords:

  matrix(n_knots, 2) of knot (lon, lat).

- z_spatial_draws:

  matrix(n_draws, n_knots) of standardized GP knot effects.

- ls_gp_draws:

  numeric(n_draws), GP length scale in caller-provided units (assumed
  already standardized for the legacy code path).

- sigma_gp_draws:

  numeric(n_draws), GP marginal SD draws.

## Value

matrix(n_draws, 1) of predicted GP values at the site.
