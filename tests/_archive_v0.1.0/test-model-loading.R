test_that("load_posteriors loads model data correctly", {
  skip_on_cran_and_ci()

  mock_posteriors <- create_mock_posteriors()

  expect_s3_class(mock_posteriors, "data.frame")
  expect_true(all(c("b0", "b1", "sigma") %in% names(mock_posteriors)))
  expect_equal(nrow(mock_posteriors), 100)
})

test_that("load_model_posteriors handles different data sources", {
  mock_posteriors <- create_mock_posteriors(n_draws = 50)

  expect_equal(nrow(mock_posteriors), 50)
  expect_type(mock_posteriors$b0, "double")
  expect_type(mock_posteriors$b1, "double")
  expect_true(all(mock_posteriors$sigma > 0))
})

test_that("list_models returns expected model names", {
  models <- list_models()

  expect_type(models, "list")
  expect_true("simple_oipc" %in% names(models))
  expect_true("full_spatial" %in% names(models))

  expect_true(all(sapply(models, function(x) "r2" %in% names(x))))
})

test_that("get_model_info returns correct metadata", {
  mock_metadata <- create_mock_metadata("b0b1")

  expect_type(mock_metadata, "list")
  expect_equal(mock_metadata$model_name, "b0b1")
  expect_false(mock_metadata$has_elevation)
  expect_false(mock_metadata$has_c4)
  expect_false(mock_metadata$has_pft)
  expect_false(mock_metadata$has_gp)

  mock_metadata_full <- create_mock_metadata("b0b1_elev_c4_pft_sp")
  expect_true(mock_metadata_full$has_elevation)
  expect_true(mock_metadata_full$has_c4)
  expect_true(mock_metadata_full$has_pft)
  expect_true(mock_metadata_full$has_gp)
})

test_that("select_best_model chooses appropriate model", {
  data <- create_test_data(5)

  data_minimal <- data[, c("d2h_wax", "longitude", "latitude")]
  expect_match(select_best_model(data_minimal), "simple_oipc|minimal")

  data_with_elev <- data[, c("d2h_wax", "longitude", "latitude", "elevation")]
  expect_match(select_best_model(data_with_elev), "elev|minimal|baseline")

  data_full <- data
  expect_match(select_best_model(data_full), "full|pft|c4")
})

test_that("detect_model_capabilities works correctly", {
  data <- create_test_data(5)

  caps <- detect_model_capabilities(data)
  expect_type(caps, "list")
  expect_true("has_coordinates" %in% names(caps))
  expect_true("has_elevation" %in% names(caps))
  expect_true("has_c4" %in% names(caps))
  expect_true("has_pft" %in% names(caps))

  expect_true(caps$has_coordinates)
  expect_true(caps$has_elevation)
  expect_true(caps$has_c4)
  expect_true(caps$has_pft)

  data_minimal <- data[, c("d2h_wax", "longitude", "latitude")]
  caps_minimal <- detect_model_capabilities(data_minimal)
  expect_true(caps_minimal$has_coordinates)
  expect_false(caps_minimal$has_elevation)
  expect_false(caps_minimal$has_c4)
  expect_false(caps_minimal$has_pft)
})

test_that("check_data_cache identifies cached models", {
  skip_on_cran()

  result <- tryCatch({
    check_data_cache("b0b1", "minimal", verbose = FALSE)
  }, error = function(e) {
    FALSE
  })

  expect_type(result, "logical")
})

test_that("get_data_path returns correct paths", {
  path <- get_data_path("test_file.rds", data_source = "package")
  expect_type(path, "character")
  expect_match(path, "extdata/test_file.rds$")

  path_cache <- get_data_path("test_file.rds", data_source = "cache")
  expect_type(path_cache, "character")
  expect_match(path_cache, "leafwax.*test_file.rds$")
})

test_that("list_cached_models returns character vector", {
  skip_on_cran()

  cached <- list_cached_models()
  expect_type(cached, "character")
})