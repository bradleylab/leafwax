# R/spatial_interpolation.R

#' @importFrom stats dist
NULL

#' Predict spatial random effect at new location using mPP
#'
#' @param coords_std Standardized coordinates (length 2 vector)
#' @param knot_coords Matrix of knot coordinates (n_knots x 2)
#' @param z_spatial_draws Matrix of spatial random effects at knots (n_draws x n_knots)
#' @param ls_gp_draws Vector of GP length scale parameters (n_draws)
#' @param sigma_gp_draws Vector of GP variance parameters (n_draws)
#' @return Vector of predicted spatial effects (n_draws)
#' @export
predict_spatial_mpp <- function(coords_std, knot_coords, z_spatial_draws, 
                               ls_gp_draws, sigma_gp_draws) {
  
  n_draws <- nrow(z_spatial_draws)
  spatial_pred <- numeric(n_draws)
  
  for (i in 1:n_draws) {
    # Get parameters for this draw
    ls <- ls_gp_draws[i]
    sigma_gp <- sigma_gp_draws[i]
    z_knots <- z_spatial_draws[i, ]
    
    # Compute covariance between new location and knots
    # Using same kernel as in Stan model
    dists <- sqrt((coords_std[1] - knot_coords[,1])^2 + 
                  (coords_std[2] - knot_coords[,2])^2)
    k_cross <- sigma_gp^2 * exp(-dists / ls)
    
    # For mPP, we need the knot covariance matrix
    knot_dists <- as.matrix(dist(knot_coords))
    K_knots <- sigma_gp^2 * exp(-knot_dists / ls)
    
    # Add jitter for numerical stability
    K_knots <- K_knots + diag(1e-4, nrow(K_knots))
    
    # Kriging prediction
    # E[f(s) | f(knots)] = k_cross * K_knots^{-1} * z_knots
    spatial_pred[i] <- t(k_cross) %*% solve(K_knots, z_knots)
  }
  
  return(spatial_pred)
}
