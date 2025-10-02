# Complete workflow example for leafwax package
# This script demonstrates the full functionality of the refactored API

library(leafwax)

cat("===== leafwax Complete Workflow Example =====\n\n")

# ============================================================================
# 1. Explore available models
# ============================================================================

cat("1. EXPLORING AVAILABLE MODELS\n")
cat(strrep("-", 50), "\n\n")

# List all models with their requirements
models_df <- list_models(check_data = TRUE)

# Show model statistics
cat("\nModel Statistics:\n")
cat("  Total models:", nrow(models_df), "\n")
cat("  Spatial models:", sum(models_df$has_spatial), "\n")
cat("  Models with data:", sum(models_df$data_status != "Not available"), "\n\n")

# ============================================================================
# 2. Load and validate example data
# ============================================================================

cat("2. LOADING EXAMPLE DATA\n")
cat(strrep("-", 50), "\n\n")

data(example_data)
cat("Loaded example_data with", nrow(example_data), "sites\n")
cat("Variables:", paste(names(example_data), collapse = ", "), "\n\n")

# Validate inputs for different models
cat("Validating inputs for b0b1 model:\n")
validated_b0b1 <- validate_inputs(
  d2h_wax = example_data$d2h_wax,
  longitude = example_data$longitude,
  latitude = example_data$latitude,
  model_name = "b0b1"
)
cat("  ✓ Validation successful\n")

cat("\nValidating inputs for b0b1_elev model:\n")
validated_elev <- validate_inputs(
  d2h_wax = example_data$d2h_wax,
  longitude = example_data$longitude,
  latitude = example_data$latitude,
  elevation = example_data$elevation,
  model_name = "b0b1_elev"
)
cat("  ✓ Validation successful\n\n")

# ============================================================================
# 3. Simple prediction with automatic model selection
# ============================================================================

cat("3. SIMPLE PREDICTION WITH AUTO MODEL SELECTION\n")
cat(strrep("-", 50), "\n\n")

# Automatic model selection based on available data
selected_model <- select_best_model(
  has_elevation = TRUE,
  has_c4 = TRUE,
  has_pft = TRUE,
  prefer_spatial = TRUE,
  verbose = TRUE
)

# Make predictions using the main API function
cat("\nMaking predictions with automatic model selection:\n")
tryCatch({
  results_auto <- predict_d2h_precip(
    example_data,
    model = "auto",
    verbose = TRUE
  )

  cat("\nResults summary:\n")
  print(head(results_auto[, c("d2h_precip_mean", "d2h_precip_sd", "model_used")]))

}, error = function(e) {
  cat("Note: Prediction requires model data. Download with:\n")
  cat("  download_model_data('", selected_model, "', 'standard')\n")
})

# ============================================================================
# 4. Using specific models
# ============================================================================

cat("\n4. USING SPECIFIC MODELS\n")
cat(strrep("-", 50), "\n\n")

# Try different models based on available covariates
models_to_try <- c("b0b1", "b0b1_elev")

for (model in models_to_try) {
  cat("Trying model:", model, "\n")

  # Check if data is available
  if (check_data_cache(model, "standard", verbose = FALSE)) {
    cat("  Data available, making predictions...\n")

    tryCatch({
      results <- predict_d2h_precip(
        data = example_data[1:3, ],  # Use first 3 sites
        model = model,
        verbose = FALSE
      )

      cat("  Mean predictions:", round(results$d2h_precip_mean, 1), "\n")

    }, error = function(e) {
      cat("  Error:", e$message, "\n")
    })
  } else {
    cat("  Data not available. Download with: download_model_data('", model, "')\n")
  }
  cat("\n")
}

# ============================================================================
# 5. Batch processing with progress
# ============================================================================

cat("5. BATCH PROCESSING\n")
cat(strrep("-", 50), "\n\n")

# Create a larger dataset for batch processing
large_data <- data.frame(
  site_id = paste0("BATCH_", 1:50),
  d2h_wax = rnorm(50, mean = -120, sd = 20),
  d2h_wax_sd = rep(3, 50),
  longitude = runif(50, -120, -80),
  latitude = runif(50, 30, 45),
  elevation = runif(50, 0, 2000),
  c4_fraction = runif(50, 0, 0.5)
)

cat("Created batch dataset with", nrow(large_data), "sites\n\n")

# Process in batches
cat("Processing in batches:\n")
tryCatch({
  batch_results <- batch_predict(
    large_data,
    model = "b0b1",
    chunk_size = 10,
    progress = TRUE
  )

  cat("\nBatch processing complete\n")
  cat("Results shape:", nrow(batch_results), "x", ncol(batch_results), "\n")

}, error = function(e) {
  cat("Batch processing requires model data\n")
})

# ============================================================================
# 6. Model comparison
# ============================================================================

cat("\n6. MODEL COMPARISON\n")
cat(strrep("-", 50), "\n\n")

# Compare predictions from multiple models
cat("Comparing models (if data available):\n")

models_to_compare <- c("b0b1", "b0b1_elev")
available_for_compare <- character()

for (model in models_to_compare) {
  if (check_data_cache(model, "standard", verbose = FALSE)) {
    available_for_compare <- c(available_for_compare, model)
  }
}

if (length(available_for_compare) > 0) {
  cat("Comparing:", paste(available_for_compare, collapse = ", "), "\n")

  tryCatch({
    comparison <- compare_models(
      example_data[1:3, ],
      models = available_for_compare,
      return_all = TRUE,
      progress = FALSE
    )

    cat("\nComparison results:\n")
    print(comparison[, grep("mean", names(comparison))])

  }, error = function(e) {
    cat("Error in comparison:", e$message, "\n")
  })
} else {
  cat("No models have data available for comparison\n")
}

# ============================================================================
# 7. Using lookup tables for spatial models
# ============================================================================

cat("\n7. USING LOOKUP TABLES\n")
cat(strrep("-", 50), "\n\n")

# Load mini lookup table for demonstration
data(mini_lookup_table)

cat("Using pre-computed lookup table:\n")
cat("  Grid:", nrow(mini_lookup_table$grid), "cells\n")
cat("  Resolution:", mini_lookup_table$metadata$resolution, "degrees\n\n")

# Get spatial parameters for test locations
test_sites <- data.frame(
  longitude = c(-100, -95, -90),
  latitude = c(35, 37, 40)
)

cat("Getting spatial parameters for test sites:\n")
spatial_params <- get_spatial_params(
  longitude = test_sites$longitude,
  latitude = test_sites$latitude,
  lookup_table = mini_lookup_table,
  method = "bilinear",
  return_draws = FALSE
)

print(spatial_params[, c("longitude", "latitude", "spatial_mean", "spatial_sd")])

# ============================================================================
# 8. Data management
# ============================================================================

cat("\n8. DATA MANAGEMENT\n")
cat(strrep("-", 50), "\n\n")

# Check cache status
cache_info <- get_cache_info()
cat("Cache status:\n")
cat("  Directory:", get_data_path(create = FALSE), "\n")
cat("  Total size:", cache_info$total_size_mb, "MB\n")
cat("  File count:", cache_info$file_count, "\n\n")

# List cached models
cached <- list_cached_models(verbose = FALSE)
if (length(cached) > 0) {
  cat("Cached models:", paste(cached, collapse = ", "), "\n")
} else {
  cat("No models cached\n")
}

# Show how to download data
cat("\nTo download model data:\n")
cat("  download_model_data('b0b1_sp', 'standard')  # 2000 draws\n")
cat("  download_model_data('b0b1_sp', 'full')       # All draws\n")

cat("\nTo enable auto-download:\n")
cat("  options(leafwax.auto_download = TRUE)\n")

# ============================================================================
# 9. Memory monitoring
# ============================================================================

cat("\n9. MEMORY USAGE\n")
cat(strrep("-", 50), "\n\n")

memory_stats <- monitor_memory("Current memory usage:")

# ============================================================================
# Summary
# ============================================================================

cat("\n", strrep("=", 50), "\n")
cat("WORKFLOW COMPLETE\n")
cat(strrep("=", 50), "\n\n")

cat("Key functions demonstrated:\n")
cat("  • list_models() - Explore available models\n")
cat("  • validate_inputs() - Check input data\n")
cat("  • predict_d2h_precip() - Main prediction function\n")
cat("  • batch_predict() - Process large datasets\n")
cat("  • compare_models() - Compare multiple models\n")
cat("  • get_spatial_params() - Use lookup tables\n")
cat("  • download_model_data() - Get model data\n")

cat("\nFor more information:\n")
cat("  help(package = 'leafwax')\n")
cat("  vignette('leafwax')\n")