#!/usr/bin/env Rscript

# Synchronize the package's development-checkout posterior tier from an exact
# leafwax-data release checkout. The data repository is the sole canonical
# source of complete posterior files; this script refuses files that do not
# match its manifest.

suppressPackageStartupMessages({
  library(digest)
  library(jsonlite)
})

source_dir <- Sys.getenv("LEAFWAX_DATA_DIR", unset = "")
target_dir <- file.path("inst", "extdata", "posteriors")

if (!file.exists("DESCRIPTION")) {
  stop("Run this script from the leafwax package root.")
}
if (!nzchar(source_dir)) {
  stop("Set LEAFWAX_DATA_DIR to a leafwax-data release checkout.")
}
source_dir <- normalizePath(source_dir, mustWork = TRUE)
manifest_path <- file.path(source_dir, "manifest.json")
if (!file.exists(manifest_path)) stop("Missing data manifest: ", manifest_path)

manifest <- jsonlite::fromJSON(manifest_path)
expected_files <- sort(names(manifest$files))
actual_files <- sort(basename(list.files(
  source_dir, pattern = "_posterior\\.rds$", full.names = TRUE
)))
if (!identical(actual_files, expected_files)) {
  stop("Source posterior file set does not match manifest.json")
}
if (length(expected_files) != as.integer(manifest$n_models)) {
  stop("Manifest n_models does not match its file list")
}

verify_one <- function(path, entry) {
  identical(
    digest::digest(file = path, algo = "sha256"),
    as.character(entry$sha256)
  ) && identical(
    as.numeric(unname(file.info(path)$size)),
    as.numeric(entry$size_bytes)
  )
}

source_paths <- file.path(source_dir, expected_files)
valid <- vapply(seq_along(source_paths), function(i) {
  verify_one(source_paths[[i]], manifest$files[[expected_files[[i]]]])
}, logical(1))
if (!all(valid)) {
  stop("Source files failed manifest verification: ",
       paste(expected_files[!valid], collapse = ", "))
}

dir.create(target_dir, recursive = TRUE, showWarnings = FALSE)
copied <- file.copy(source_paths, file.path(target_dir, expected_files),
                    overwrite = TRUE)
if (!all(copied)) {
  stop("Could not synchronize: ", paste(expected_files[!copied], collapse = ", "))
}

target_valid <- vapply(seq_along(expected_files), function(i) {
  verify_one(
    file.path(target_dir, expected_files[[i]]),
    manifest$files[[expected_files[[i]]]]
  )
}, logical(1))
if (!all(target_valid)) stop("Synchronized files failed post-copy verification")

cat(
  "Synchronized", length(expected_files), "posterior files from data version",
  manifest$version, "\n"
)
cat("Run Rscript data-raw/regenerate_posteriors_light.R next.\n")
