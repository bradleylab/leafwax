#!/usr/bin/env Rscript

output_dir <- file.path("inst", "extdata", "example_records")
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

records <- list(
  list(
    id = "LS13WASU",
    url = "https://lipdverse.org/iso2k/1_0_0/LS13WASU.lpd",
    source_csv = "bag/data/LS13WASU.paleo1measurement1.csv",
    output_file = "LS13WASU_C29_d2H.csv",
    source_doi = "10.1177/0959683613486941",
    d2h_col = 1,
    age_col = 2,
    age_transform = function(year_ce) 1950 - year_ce
  ),
  list(
    id = "LS14LASO",
    url = "https://lipdverse.org/iso2k/1_0_0/LS14LASO.lpd",
    source_csv = "bag/data/LS14LASO.paleo1measurement1.csv",
    output_file = "LS14LASO_C29_d2H.csv",
    source_doi = "10.1177/0959683614534741",
    d2h_col = 5,
    age_col = 3,
    age_transform = identity
  )
)

extract_record <- function(record) {
  archive <- tempfile(fileext = ".lpd")
  on.exit(unlink(archive), add = TRUE)

  utils::download.file(record$url, archive, mode = "wb", quiet = TRUE)

  metadata <- paste(
    readLines(unz(archive, "bag/data/metadata.jsonld"), warn = FALSE),
    collapse = "\n"
  )
  required_metadata <- c(
    '"measurementMaterial": "n-alkane"',
    '"measurementMaterialDetail": "C29"',
    paste0('"doi": "', record$source_doi, '"')
  )
  missing_metadata <- !vapply(required_metadata, grepl, logical(1),
                              x = metadata, fixed = TRUE)
  if (any(missing_metadata)) {
    stop(
      record$id, " metadata did not contain expected fields: ",
      paste(required_metadata[missing_metadata], collapse = ", "),
      call. = FALSE
    )
  }

  source_data <- utils::read.csv(
    unz(archive, record$source_csv),
    header = FALSE,
    stringsAsFactors = FALSE
  )

  age <- record$age_transform(as.numeric(source_data[[record$age_col]]))
  d2h <- as.numeric(source_data[[record$d2h_col]])
  keep <- is.finite(age) & is.finite(d2h)

  if (any(!keep)) {
    message(record$id, ": dropping ", sum(!keep),
            " row(s) with missing age or d2H.")
  }

  out <- data.frame(
    age_yrBP = age[keep],
    d2H_wax = d2h[keep]
  )

  utils::write.csv(
    out,
    file.path(output_dir, record$output_file),
    row.names = FALSE,
    na = ""
  )
}

invisible(lapply(records, extract_record))

unlink(file.path(output_dir, c("LS14FEZA_d2H.csv", "LS16THQI01_d2H.csv")))
