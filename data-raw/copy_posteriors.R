# Updated copy_posteriors.R
source_dir <- "~/shared/leafwax_spatial/d2H_model_v12_v4/model_output"
dest_dir <- "~/shared/leafwax_spatial/leafwax/inst/extdata/posterior_draws"

models <- c(
  "b0b1", "b0b1_c4", "b0b1_c4_pft", "b0b1_c4_pft_sp", "b0b1_c4_sp",
  "b0b1_elev", "b0b1_elev_c4", "b0b1_elev_c4_pft", "b0b1_elev_c4_pft_sp",
  "b0b1_elev_c4_sp", "b0b1_elev_pft", "b0b1_elev_pft_sp", "b0b1_elev_sp",
  "b0b1_pft", "b0b1_pft_sp", "b0b1_sp"
)

for (model in models) {
  # Use the COMPLETE posteriors
  source_file <- file.path(source_dir, model, "posterior_draws_complete.rds")
  dest_file <- file.path(dest_dir, paste0(model, ".rds"))
  
  if (file.exists(source_file)) {
    file.copy(source_file, dest_file, overwrite = TRUE)
    cat("Copied:", model, "\n")
  } else {
    cat("WARNING: Not found:", source_file, "\n")
  }
}