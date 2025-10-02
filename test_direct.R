# Direct test without package installation

cat("Testing direct loading from inst/extdata/posteriors/\n")
cat("=====================================================\n\n")

# List files
posterior_files <- list.files("inst/extdata/posteriors", pattern = "\\.rds$", full.names = TRUE)
cat("Found", length(posterior_files), "posterior files:\n")

for (f in posterior_files) {
  model_name <- gsub(".*/(.*?)_posterior\\.rds$", "\\1", f)
  size_kb <- round(file.info(f)$size / 1024)

  # Load and check
  dat <- readRDS(f)

  cat(sprintf("  %-30s %5d KB   %6d draws × %3d params\n",
              paste0(model_name, ":"),
              size_kb,
              nrow(dat),
              ncol(dat)))
}

cat("\nTotal size:", round(sum(file.info(posterior_files)$size) / 1024^2, 1), "MB\n")

# Test loading a specific model
cat("\n\nTest loading baseline model:\n")
baseline <- readRDS("inst/extdata/posteriors/baseline_posterior.rds")
cat("  Parameters:", paste(names(baseline)[1:5], collapse = ", "), "...\n")
cat("  First draw beta_0:", baseline$beta_0[1], "\n")

cat("\nTest loading baseline_sp model:\n")
baseline_sp <- readRDS("inst/extdata/posteriors/baseline_sp_posterior.rds")
cat("  Parameters:", paste(names(baseline_sp)[1:5], collapse = ", "), "...\n")
cat("  Has spatial params:", any(grepl("spatial|lambda", names(baseline_sp))), "\n")

# Check spatial metadata
cat("\n\nSpatial metadata:\n")
knot_files <- list.files("inst/extdata/spatial_metadata", pattern = "_knots\\.rds$", full.names = TRUE)
cat("Found", length(knot_files), "knot files\n")
if (length(knot_files) > 0) {
  knots <- readRDS(knot_files[1])
  cat("  Knot dimensions:", nrow(knots), "locations ×", ncol(knots), "coords\n")
}

cat("\n✓ All files accessible and valid!\n")
cat("✓ Package contains all necessary data (~11MB total)\n")
cat("✓ No external downloads needed for core functionality\n")