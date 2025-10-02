# Test script for lookup table system
library(leafwax)

# Test 1: Generate global grid
cat("Test 1: Generating global grid\n")
grid <- generate_global_grid()
cat("  Grid dimensions:", nrow(grid), "cells\n")
cat("  Columns:", paste(names(grid), collapse = ", "), "\n")
cat("  Longitude range:", range(grid$lon), "\n")
cat("  Latitude range:", range(grid$lat), "\n\n")

# Test 2: Generate custom grid
cat("Test 2: Generating custom grid (North America)\n")
na_grid <- generate_global_grid(
  lon_min = -130, lon_max = -60,
  lat_min = 25, lat_max = 50,
  resolution = 2
)
cat("  Grid dimensions:", nrow(na_grid), "cells\n")
cat("  Resolution: 2 degrees\n\n")

# Test 3: Create lookup table for spatial model
cat("Test 3: Creating lookup table for spatial model\n")
tryCatch({
  # Try with b0b1_sp model (if it exists)
  lookup <- create_lookup_table(
    model_name = "b0b1_sp",
    grid = na_grid,  # Use smaller grid for testing
    n_draws = 50,     # Use fewer draws for testing
    verbose = TRUE
  )

  cat("\n  Lookup table created successfully!\n")
  print(lookup)

  # Test 4: Get spatial parameters for specific locations
  cat("\nTest 4: Getting spatial parameters for specific locations\n")

  # Test locations
  test_lons <- c(-120, -100, -80)
  test_lats <- c(45, 35, 40)

  # Get spatial parameters using nearest neighbor
  params_nearest <- get_spatial_params(
    longitude = test_lons,
    latitude = test_lats,
    lookup_table = lookup,
    method = "nearest",
    return_draws = FALSE
  )

  cat("  Nearest neighbor method:\n")
  print(params_nearest)

  # Get spatial parameters using bilinear interpolation
  params_bilinear <- get_spatial_params(
    longitude = test_lons,
    latitude = test_lats,
    lookup_table = lookup,
    method = "bilinear",
    return_draws = FALSE
  )

  cat("\n  Bilinear interpolation method:\n")
  print(params_bilinear)

  # Test 5: Validate lookup table
  cat("\nTest 5: Validating lookup table\n")
  is_valid <- validate_lookup_table(lookup)
  cat("  Lookup table is valid:", is_valid, "\n")

}, error = function(e) {
  cat("  Error:", e$message, "\n")
  cat("  This may be because b0b1_sp model is not available.\n")
  cat("  Available models:\n")
  models <- list_available_models()
  cat("   ", paste(models, collapse = ", "), "\n")
})

# Test 6: Check caching functionality
cat("\nTest 6: Testing cache functionality\n")
cache_dir <- tempdir()
cat("  Cache directory:", cache_dir, "\n")

tryCatch({
  # Create and cache a lookup table
  lookup_cached <- create_lookup_table(
    model_name = "b0b1_sp",
    grid = na_grid,
    n_draws = 50,
    cache_dir = cache_dir,
    verbose = FALSE
  )

  # List cached files
  cached_files <- list.files(cache_dir, pattern = "lookup_.*\\.rds")
  cat("  Cached files:", paste(cached_files, collapse = ", "), "\n")

  # Try loading from cache (should be fast)
  t1 <- Sys.time()
  lookup_from_cache <- create_lookup_table(
    model_name = "b0b1_sp",
    grid = na_grid,
    n_draws = 50,
    cache_dir = cache_dir,
    verbose = FALSE
  )
  t2 <- Sys.time()

  cat("  Time to load from cache:", format(t2 - t1), "\n")

}, error = function(e) {
  cat("  Caching test failed:", e$message, "\n")
})

cat("\nAll tests completed!\n")