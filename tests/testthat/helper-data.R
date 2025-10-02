# Helper functions and mock data for tests

# Create mock data for testing
create_test_data <- function(n = 10) {
  data.frame(
    site_id = paste0("TEST_", seq_len(n)),
    d2h_wax = rnorm(n, mean = -140, sd = 20),
    d2h_wax_sd = rep(3, n),
    d2h_wax_err = rep(3, n),
    longitude = runif(n, -120, -80),
    latitude = runif(n, 25, 45),
    elevation = runif(n, 0, 3000),
    c4_fraction = runif(n, 0, 1),
    pft_tree = runif(n, 0.2, 0.6),
    pft_shrub = runif(n, 0.1, 0.3),
    pft_grass = runif(n, 0.2, 0.5),
    stringsAsFactors = FALSE
  )
}

# Create mock posterior draws
create_mock_posteriors <- function(n_draws = 100, n_params = 3) {
  draws <- matrix(
    rnorm(n_draws * n_params),
    nrow = n_draws,
    ncol = n_params
  )
  colnames(draws) <- c("b0", "b1", "sigma")

  # Make realistic values
  draws[, "b0"] <- rnorm(n_draws, mean = 20, sd = 5)
  draws[, "b1"] <- rnorm(n_draws, mean = 0.8, sd = 0.05)
  draws[, "sigma"] <- abs(rnorm(n_draws, mean = 10, sd = 2))

  return(as.data.frame(draws))
}

# Create mock model metadata
create_mock_metadata <- function(model_name = "b0b1") {
  list(
    model_name = model_name,
    has_elevation = grepl("elev", model_name),
    has_c4 = grepl("c4", model_name),
    has_pft = grepl("pft", model_name),
    has_gp = grepl("sp", model_name),
    parameters = c("b0", "b1", "sigma"),
    n_parameters = 3,
    n_gp_knots = if (grepl("sp", model_name)) 120 else NULL
  )
}

# Create mock lookup table
create_mock_lookup_table <- function(n_cells = 9) {
  grid <- expand.grid(
    lon = seq(-110, -90, by = 10),
    lat = seq(30, 40, by = 5)
  )
  grid <- grid[seq_len(n_cells), ]
  grid$cell_id <- seq_len(nrow(grid))

  # Create fake spatial effects
  n_draws <- 50
  spatial_effects <- matrix(
    rnorm(nrow(grid) * n_draws, mean = 0, sd = 5),
    nrow = nrow(grid),
    ncol = n_draws
  )

  lookup <- list(
    model_name = "test_model",
    grid = grid,
    spatial_effects = spatial_effects,
    n_draws = n_draws,
    metadata = list(
      created = Sys.Date(),
      resolution = 10,
      bounds = list(
        lon = range(grid$lon),
        lat = range(grid$lat)
      ),
      gp_params = list(
        ls_mean = 20,
        ls_sd = 5,
        sigma_mean = 5,
        sigma_sd = 1
      )
    )
  )

  class(lookup) <- c("leafwax_lookup_table", "list")
  return(lookup)
}

# Skip tests that require external resources on CRAN
skip_on_cran_and_ci <- function() {
  skip_on_cran()
  if (Sys.getenv("CI") != "") {
    skip("Skipping on CI")
  }
}

# Check if a model is available for testing
model_available <- function(model_name) {
  tryCatch({
    check_data_cache(model_name, "minimal", verbose = FALSE)
  }, error = function(e) {
    FALSE
  })
}