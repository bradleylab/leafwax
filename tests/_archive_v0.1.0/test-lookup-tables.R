test_that("generate_global_grid creates correct grid", {
  grid <- generate_global_grid(resolution = 10)

  expect_s3_class(grid, "data.frame")
  expect_true(all(c("longitude", "latitude", "cell_id") %in% names(grid)))

  expect_equal(min(grid$longitude), -175)
  expect_equal(max(grid$longitude), 175)
  expect_equal(min(grid$latitude), -85)
  expect_equal(max(grid$latitude), 85)

  expected_cells <- 36 * 18
  expect_equal(nrow(grid), expected_cells)
})

test_that("generate_fibonacci_sphere creates uniform points", {
  points <- generate_fibonacci_sphere(100)

  expect_type(points, "list")
  expect_equal(length(points$lon), 100)
  expect_equal(length(points$lat), 100)

  expect_true(all(points$lon >= -180 & points$lon <= 180))
  expect_true(all(points$lat >= -90 & points$lat <= 90))
})

test_that("create_lookup_table builds correct structure", {
  skip_on_cran_and_ci()

  mock_lookup <- create_mock_lookup_table()

  expect_s3_class(mock_lookup, "leafwax_lookup_table")
  expect_type(mock_lookup, "list")

  expect_true("grid" %in% names(mock_lookup))
  expect_true("spatial_effects" %in% names(mock_lookup))
  expect_true("metadata" %in% names(mock_lookup))

  expect_s3_class(mock_lookup$grid, "data.frame")
  expect_true(is.matrix(mock_lookup$spatial_effects))

  expect_equal(nrow(mock_lookup$spatial_effects), nrow(mock_lookup$grid))
  expect_equal(ncol(mock_lookup$spatial_effects), mock_lookup$n_draws)
})

test_that("get_spatial_params performs interpolation", {
  lookup <- create_mock_lookup_table()

  params <- get_spatial_params(
    lookup,
    longitude = -100,
    latitude = 35,
    method = "nearest"
  )

  expect_type(params, "double")
  expect_equal(length(params), lookup$n_draws)

  params_bilinear <- get_spatial_params(
    lookup,
    longitude = -100,
    latitude = 35,
    method = "bilinear"
  )

  expect_type(params_bilinear, "double")
  expect_equal(length(params_bilinear), lookup$n_draws)
})

test_that("validate_lookup_table checks structure", {
  lookup <- create_mock_lookup_table()
  expect_true(validate_lookup_table(lookup))

  bad_lookup <- lookup
  bad_lookup$grid <- NULL
  expect_false(suppressWarnings(validate_lookup_table(bad_lookup)))

  bad_lookup2 <- lookup
  bad_lookup2$spatial_effects <- matrix(0, nrow = 5, ncol = 10)
  expect_false(suppressWarnings(validate_lookup_table(bad_lookup2)))
})

test_that("create_regional_lookup creates subset", {
  skip_on_cran_and_ci()

  bounds <- list(
    lon = c(-110, -90),
    lat = c(30, 45)
  )

  regional_grid <- generate_global_grid(resolution = 5)
  regional_grid <- regional_grid[
    regional_grid$longitude >= bounds$lon[1] &
    regional_grid$longitude <= bounds$lon[2] &
    regional_grid$latitude >= bounds$lat[1] &
    regional_grid$latitude <= bounds$lat[2], ]

  expect_true(all(regional_grid$longitude >= bounds$lon[1]))
  expect_true(all(regional_grid$longitude <= bounds$lon[2]))
  expect_true(all(regional_grid$latitude >= bounds$lat[1]))
  expect_true(all(regional_grid$latitude <= bounds$lat[2]))

  expect_lt(nrow(regional_grid), 36 * 18)
})

test_that("benchmark_lookup measures performance", {
  lookup <- create_mock_lookup_table()

  result <- benchmark_lookup(
    lookup,
    n_points = 10,
    verbose = FALSE
  )

  expect_type(result, "list")
  expect_true("mean_time_ms" %in% names(result))
  expect_true("total_time_s" %in% names(result))
  expect_true("points_per_second" %in% names(result))

  expect_true(result$mean_time_ms > 0)
  expect_true(result$points_per_second > 0)
})

test_that("use_lookup_if_available handles missing lookup", {
  params <- use_lookup_if_available(
    model_name = "nonexistent_model",
    longitude = -100,
    latitude = 35,
    n_draws = 50,
    verbose = FALSE
  )

  expect_null(params)
})

test_that("interpolation handles edge cases", {
  lookup <- create_mock_lookup_table()

  params_edge <- get_spatial_params(
    lookup,
    longitude = -180,
    latitude = 90,
    method = "nearest"
  )
  expect_type(params_edge, "double")

  params_outside <- get_spatial_params(
    lookup,
    longitude = -200,
    latitude = 95,
    method = "nearest"
  )
  expect_type(params_outside, "double")
})

test_that("cache_all_lookup_tables respects memory limits", {
  skip_on_cran_and_ci()

  expect_message(
    cache_all_lookup_tables(
      models = "minimal",
      n_draws = 10,
      max_memory_gb = 0.001,
      verbose = TRUE
    ),
    "memory"
  )
})

test_that("lookup table metadata is preserved", {
  lookup <- create_mock_lookup_table()

  expect_type(lookup$metadata, "list")
  expect_true("created" %in% names(lookup$metadata))
  expect_true("resolution" %in% names(lookup$metadata))
  expect_true("bounds" %in% names(lookup$metadata))
  expect_true("gp_params" %in% names(lookup$metadata))

  expect_s3_class(lookup$metadata$created, "Date")
  expect_type(lookup$metadata$resolution, "double")
  expect_type(lookup$metadata$bounds, "list")
})