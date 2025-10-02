# subset_and_organize_data.R
# Creates subset versions of the data for the R package

library(tidyverse)

# Configuration
N_DRAWS_TO_KEEP <- 2000  # Number of posterior draws to keep per model
PACKAGE_DIR <- "~/shared/leafwax_spatial/leafwax"

setwd(PACKAGE_DIR)

cat("Subsetting posterior draws for leafwax package\n")
cat(strrep("=", 60), "\n\n")

# Create directories for organization
dir.create("inst/extdata/posterior_draws_full", showWarnings = FALSE)
dir.create("inst/extdata/model_metadata_full", showWarnings = FALSE)

# Step 1: Move complete files to 'full' directories
cat("Step 1: Organizing full posterior draws...\n")

# Move complete draws
complete_files <- list.files("inst/extdata/posterior_draws", 
                            pattern = "_complete_draws.rds$", 
                            full.names = TRUE)

for (file in complete_files) {
  new_path <- file.path("inst/extdata/posterior_draws_full", basename(file))
  if (file.exists(file)) {
    file.rename(file, new_path)
    cat("  Moved:", basename(file), "\n")
  }
}

# Move complete metadata
metadata_files <- list.files("inst/extdata/model_metadata", 
                            pattern = "_complete.rds$", 
                            full.names = TRUE)

for (file in metadata_files) {
  new_path <- file.path("inst/extdata/model_metadata_full", basename(file))
  if (file.exists(file)) {
    file.rename(file, new_path)
    cat("  Moved:", basename(file), "\n")
  }
}

# Step 2: Create subset versions for the package
cat("\nStep 2: Creating subset versions for package...\n")

# Get list of models
model_names <- gsub("_complete_draws.rds", "", 
                   basename(list.files("inst/extdata/posterior_draws_full", 
                                      pattern = "_complete_draws.rds$")))

for (model_name in model_names) {
  cat("\nProcessing model:", model_name, "\n")
  
  # Load full draws
  full_draws_file <- file.path("inst/extdata/posterior_draws_full", 
                               paste0(model_name, "_complete_draws.rds"))
  
  if (!file.exists(full_draws_file)) {
    cat("  WARNING: Full draws not found\n")
    next
  }
  
  # Read full data
  full_draws <- readRDS(full_draws_file)
  n_total <- nrow(full_draws)
  cat("  Total draws:", n_total, "\n")
  
  # Subset draws
  n_keep <- min(N_DRAWS_TO_KEEP, n_total)
  set.seed(123)  # For reproducibility
  keep_rows <- sort(sample(n_total, n_keep))
  subset_draws <- full_draws[keep_rows, ]
  
  # Save subset version with standard name
  subset_file <- file.path("inst/extdata/posterior_draws", 
                          paste0(model_name, ".rds"))
  saveRDS(subset_draws, subset_file, compress = "xz")
  
  size_mb <- round(file.size(subset_file) / 1024 / 1024, 1)
  cat("  Created subset:", n_keep, "draws,", size_mb, "MB\n")
  
  # Also copy metadata (these are small, so keep full version)
  metadata_full <- file.path("inst/extdata/model_metadata_full", 
                            paste0(model_name, "_complete.rds"))
  metadata_pkg <- file.path("inst/extdata/model_metadata", 
                           paste0(model_name, ".rds"))
  
  if (file.exists(metadata_full)) {
    file.copy(metadata_full, metadata_pkg, overwrite = TRUE)
  }
}

# Step 3: Clean up other files
cat("\nStep 3: Cleaning up...\n")

# Remove old summary files (not needed)
summary_files <- list.files("inst/extdata/posterior_draws", 
                           pattern = "_summary.rds$", 
                           full.names = TRUE)
for (file in summary_files) {
  file.remove(file)
  cat("  Removed:", basename(file), "\n")
}

# Step 4: Create data documentation
cat("\nStep 4: Creating data documentation...\n")

data_info <- list(
  subset_draws = N_DRAWS_TO_KEEP,
  models = model_names,
  creation_date = Sys.time(),
  note = "Full posterior draws available in posterior_draws_full/"
)

saveRDS(data_info, "inst/extdata/data_info.rds")

# Step 5: Update .Rbuildignore to exclude full data
cat("\nStep 5: Updating .Rbuildignore...\n")

rbuildignore_content <- c(
  "^.*\\.Rproj$",
  "^\\.Rproj\\.user$",
  "^inst/extdata/posterior_draws_full$",
  "^inst/extdata/model_metadata_full$",
  "^subset_and_organize_data\\.R$",
  "^build_package\\.R$"
)

writeLines(rbuildignore_content, ".Rbuildignore")

# Summary
cat("\n", strrep("=", 60), "\n")
cat("Data organization complete!\n\n")

# Check final sizes
cat("Package data size:\n")
system("du -sh inst/extdata/posterior_draws/")
system("du -sh inst/extdata/model_metadata/")

cat("\nFull data size (excluded from package):\n")
system("du -sh inst/extdata/posterior_draws_full/")
system("du -sh inst/extdata/model_metadata_full/")

cat("\nPackage is now ready to build with subset data.\n")
cat("Full posterior draws are preserved in the _full directories.\n")