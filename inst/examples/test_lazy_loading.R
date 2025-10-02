# Test script for lazy loading system
library(leafwax)

cat("===== leafwax Lazy Loading Test =====\n\n")

# 1. Check current configuration
cat("1. Current Configuration:\n")
config <- leafwax_config()
for (name in names(config)) {
  cat(sprintf("   %s: %s\n", name,
              ifelse(is.null(config[[name]]), "NULL", as.character(config[[name]]))))
}

# 2. Check cache status
cat("\n2. Cache Status:\n")
cache_dir <- get_data_path(create = FALSE)
cat("   Cache directory:", ifelse(dir.exists(cache_dir), cache_dir, "Not created yet"), "\n")

cached_models <- list_cached_models(verbose = FALSE)
if (length(cached_models) > 0) {
  cat("   Cached models:", paste(cached_models, collapse = ", "), "\n")
  cache_info <- get_cache_info()
  cat("   Total size:", cache_info$total_size_mb, "MB\n")
  cat("   File count:", cache_info$file_count, "\n")
} else {
  cat("   No models cached yet\n")
}

# 3. Test model loading behavior
cat("\n3. Testing Model Loading:\n")

# Try loading a model (should fail without data)
cat("\n   Attempting to load b0b1_sp without auto-download...\n")
tryCatch({
  model <- load_posteriors("b0b1_sp",
                          auto_download = FALSE,
                          verbose = FALSE)
  cat("   Success: Model loaded from", model$source, "\n")
}, error = function(e) {
  cat("   Expected error: Model not found locally\n")
  cat("   Message:", conditionMessage(e), "\n")
})

# 4. Test data download
cat("\n4. Testing Data Download:\n")

test_model <- "b0b1"  # Use base model for testing

# Check if model exists
if (!check_data_cache(test_model, "minimal", verbose = FALSE)) {
  cat("   Downloading minimal data for", test_model, "...\n")

  # Note: This will fail if the URL doesn't exist
  # In a real deployment, you'd have the data hosted
  tryCatch({
    success <- download_model_data(
      model_name = test_model,
      data_type = "minimal",
      verbose = FALSE
    )

    if (success) {
      cat("   Download successful!\n")
    } else {
      cat("   Download failed (this is expected if data URL is not set up)\n")
    }
  }, error = function(e) {
    cat("   Download error (expected for demo):", conditionMessage(e), "\n")
  })
} else {
  cat("   Model", test_model, "already cached\n")
}

# 5. Test configuration changes
cat("\n5. Testing Configuration Changes:\n")

# Set a custom cache directory
temp_cache <- file.path(tempdir(), "leafwax_test_cache")
cat("   Setting temporary cache to:", temp_cache, "\n")

old_cache <- getOption("leafwax.cache_dir")
leafwax_set_config(cache_dir = temp_cache, persist = FALSE)

new_cache <- get_data_path(create = TRUE)
cat("   New cache directory:", new_cache, "\n")
cat("   Directory created:", dir.exists(new_cache), "\n")

# Restore original cache
if (!is.null(old_cache)) {
  options(leafwax.cache_dir = old_cache)
} else {
  options(leafwax.cache_dir = NULL)
}

# 6. Test cache management
cat("\n6. Testing Cache Management:\n")

# Get cache information
cache_info <- get_cache_info()
cat("   Cache size:", cache_info$total_size_mb, "MB\n")
cat("   File count:", cache_info$file_count, "\n")

if (cache_info$file_count > 0) {
  # Get breakdown by model
  by_model <- get_cache_info(by_model = TRUE)
  if (nrow(by_model) > 0) {
    cat("\n   Cache by model:\n")
    for (i in 1:min(3, nrow(by_model))) {
      cat(sprintf("     %s: %.2f MB (%d files)\n",
                  by_model$model[i],
                  by_model$size_mb[i],
                  by_model$file_count[i]))
    }
  }
}

# 7. Test loading with different data sources
cat("\n7. Testing Data Source Options:\n")

# Get available models in package
package_models <- list_available_models()
if (length(package_models) > 0) {
  test_model <- package_models[1]
  cat("   Testing with model:", test_model, "\n")

  # Try loading from package
  cat("   Loading from package data...\n")
  tryCatch({
    model <- load_posteriors(test_model,
                           data_source = "package",
                           verbose = FALSE)
    cat("     Success! Loaded", model$n_draws, "draws\n")
  }, error = function(e) {
    cat("     Failed:", conditionMessage(e), "\n")
  })

  # Try loading from cache
  cat("   Loading from cache...\n")
  tryCatch({
    model <- load_posteriors(test_model,
                           data_source = "cache",
                           verbose = FALSE)
    cat("     Success! Loaded", model$n_draws, "draws\n")
  }, error = function(e) {
    cat("     Not in cache\n")
  })
}

cat("\n===== Test Complete =====\n")
cat("\nTo fully test the system:\n")
cat("1. Set up a data server with model files\n")
cat("2. Configure the data URL:\n")
cat("   options(leafwax.data_url = 'your-server-url')\n")
cat("3. Enable auto-download:\n")
cat("   options(leafwax.auto_download = TRUE)\n")
cat("4. Try loading models:\n")
cat("   model <- load_posteriors('b0b1_sp')\n")