test_that("download_model_data verifies a manifest before caching", {
  source_file <- tempfile("leafwax-source-")
  writeBin(as.raw(seq_len(200) %% 256), source_file)
  filename <- "baseline_posterior.rds"
  cache_dir <- tempfile("leafwax-download-cache-")
  dir.create(cache_dir)
  on.exit(unlink(c(source_file, cache_dir), recursive = TRUE, force = TRUE),
          add = TRUE)

  manifest <- list(
    version = "3.0.0",
    files = setNames(list(list(
      sha256 = digest::digest(file = source_file, algo = "sha256"),
      size_bytes = unname(file.info(source_file)$size)
    )), filename)
  )
  jsonlite::write_json(
    manifest, file.path(cache_dir, "manifest.json"),
    auto_unbox = TRUE
  )

  testthat::local_mocked_bindings(
    get_data_url = function(...) list(list(
      url = source_file,
      filename = file.path("posteriors", filename)
    )),
    get_url_config = function() list(
      release_ready = TRUE,
      version = "3.0.0",
      release_tag = "v3.0.0"
    ),
    download_with_progress = function(url, destfile, verbose = TRUE) {
      file.copy(url, destfile, overwrite = TRUE)
    },
    .package = "leafwax"
  )

  expect_true(download_model_data(
    "baseline", cache_dir = cache_dir, verify = TRUE, verbose = FALSE
  ))
  cached <- file.path(cache_dir, "posteriors", filename)
  expect_true(file.exists(cached))
  expect_identical(
    digest::digest(file = cached, algo = "sha256"),
    manifest$files[[filename]]$sha256
  )
})

test_that("a checksum mismatch is rejected and not cached", {
  source_file <- tempfile("leafwax-source-")
  writeBin(as.raw(seq_len(200) %% 256), source_file)
  filename <- "baseline_posterior.rds"
  cache_dir <- tempfile("leafwax-download-cache-")
  dir.create(cache_dir)
  on.exit(unlink(c(source_file, cache_dir), recursive = TRUE, force = TRUE),
          add = TRUE)

  manifest <- list(
    version = "3.0.0",
    files = setNames(list(list(
      sha256 = paste(rep("0", 64), collapse = ""),
      size_bytes = unname(file.info(source_file)$size)
    )), filename)
  )
  jsonlite::write_json(
    manifest, file.path(cache_dir, "manifest.json"),
    auto_unbox = TRUE
  )

  testthat::local_mocked_bindings(
    get_data_url = function(...) list(list(
      url = source_file,
      filename = file.path("posteriors", filename)
    )),
    get_url_config = function() list(
      release_ready = TRUE,
      version = "3.0.0",
      release_tag = "v3.0.0"
    ),
    download_with_progress = function(url, destfile, verbose = TRUE) {
      file.copy(url, destfile, overwrite = TRUE)
    },
    .package = "leafwax"
  )

  expect_error(
    download_model_data(
      "baseline", cache_dir = cache_dir, verify = TRUE, verbose = FALSE
    ),
    "SHA-256 mismatch"
  )
  expect_false(file.exists(file.path(cache_dir, "posteriors", filename)))
})
