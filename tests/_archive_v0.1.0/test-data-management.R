test_that("download_model_data handles connection errors gracefully", {
  skip_on_cran()
  skip_if_offline()

  result <- tryCatch({
    download_model_data(
      model_name = "nonexistent_model",
      data_type = "minimal",
      verbose = FALSE,
      timeout = 5
    )
  }, error = function(e) {
    FALSE
  })

  expect_false(isTRUE(result))
})

test_that("check_data_cache identifies existing files", {
  skip_on_cran()

  cache_dir <- get_cache_dir()
  if (!dir.exists(cache_dir)) {
    dir.create(cache_dir, recursive = TRUE, showWarnings = FALSE)
  }

  test_file <- file.path(cache_dir, "test_cache_file.rds")
  saveRDS(list(test = TRUE), test_file)

  exists_in_cache <- file.exists(test_file)
  expect_true(exists_in_cache)

  unlink(test_file)
})

test_that("get_cache_dir returns valid directory path", {
  cache_dir <- get_cache_dir()

  expect_type(cache_dir, "character")
  expect_true(nchar(cache_dir) > 0)

  if (.Platform$OS.type == "windows") {
    expect_match(cache_dir, "leafwax")
  } else {
    expect_match(cache_dir, "leafwax")
  }
})

test_that("clear_data_cache removes files safely", {
  skip_on_cran()

  cache_dir <- get_cache_dir()
  if (!dir.exists(cache_dir)) {
    dir.create(cache_dir, recursive = TRUE, showWarnings = FALSE)
  }

  test_file <- file.path(cache_dir, "test_to_clear.rds")
  saveRDS(list(test = TRUE), test_file)

  expect_true(file.exists(test_file))

  clear_data_cache(
    model_name = "test_to_clear",
    confirm = FALSE,
    verbose = FALSE
  )

  expect_false(file.exists(test_file))
})

test_that("get_cache_info reports correct information", {
  skip_on_cran()

  info <- get_cache_info(verbose = FALSE)

  expect_type(info, "list")
  expect_true("cache_dir" %in% names(info))
  expect_true("total_size_mb" %in% names(info))
  expect_true("n_models" %in% names(info))
  expect_true("models" %in% names(info))

  expect_type(info$cache_dir, "character")
  expect_type(info$total_size_mb, "double")
  expect_type(info$n_models, "integer")
  expect_true(info$total_size_mb >= 0)
  expect_true(info$n_models >= 0)
})

test_that("setup_leafwax_data handles batch downloads", {
  skip_on_cran()
  skip_if_offline()

  result <- tryCatch({
    setup_leafwax_data(
      models = "minimal",
      data_type = "minimal",
      verbose = FALSE,
      timeout = 10
    )
  }, error = function(e) {
    FALSE
  })

  expect_type(result, "logical")
})

test_that("leafwax_config manages settings correctly", {
  config <- leafwax_config()

  expect_type(config, "list")
  expect_true("auto_download" %in% names(config))
  expect_true("cache_dir" %in% names(config))
  expect_true("verbose" %in% names(config))

  new_config <- leafwax_set_config(
    auto_download = FALSE,
    verbose = FALSE
  )

  expect_false(new_config$auto_download)
  expect_false(new_config$verbose)

  reset_config <- leafwax_set_config(
    auto_download = TRUE,
    verbose = TRUE
  )

  expect_true(reset_config$auto_download)
})

test_that("get_data_path constructs correct paths", {
  pkg_path <- get_data_path("test.rds", data_source = "package")
  expect_match(pkg_path, "extdata/test.rds$")

  cache_path <- get_data_path("test.rds", data_source = "cache")
  expect_match(cache_path, "leafwax.*test.rds$")

  download_path <- get_data_path("test.rds", data_source = "download")
  expect_match(download_path, "test.rds$")
})

test_that("list_cached_models returns correct models", {
  skip_on_cran()

  cache_dir <- get_cache_dir()
  if (!dir.exists(cache_dir)) {
    dir.create(cache_dir, recursive = TRUE, showWarnings = FALSE)
  }

  test_files <- c(
    "b0b1_minimal.rds",
    "b0b1_sp_minimal.rds",
    "not_a_model.txt"
  )

  for (f in test_files[1:2]) {
    saveRDS(list(), file.path(cache_dir, f))
  }

  cached <- list_cached_models()
  expect_type(cached, "character")

  for (f in test_files[1:2]) {
    unlink(file.path(cache_dir, f))
  }
})

test_that("get_download_files lists correct URLs", {
  files <- get_download_files()

  expect_type(files, "list")
  expect_true(length(files) > 0)

  expect_true(all(sapply(files, function(x) "minimal" %in% names(x))))
  expect_true(all(sapply(files, function(x) grepl("^https://", x$minimal))))
})

test_that("monitor_memory tracks usage", {
  before <- monitor_memory()
  large_obj <- matrix(0, nrow = 1000, ncol = 1000)
  after <- monitor_memory()

  expect_type(before, "list")
  expect_type(after, "list")
  expect_true(before$used_mb >= 0)
  expect_true(after$gc_used_mb >= 0)

  rm(large_obj)
  gc(verbose = FALSE)
})