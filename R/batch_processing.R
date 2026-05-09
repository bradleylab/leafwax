# R/batch_processing.R - Functions for batch processing with progress indicators

# Column-tolerant rbind for chunked batch results. Pads any chunk
# missing columns with NA so a successful + errored chunk mix can be
# combined without aborting. Returns a single data frame with the union
# of all input columns.
.rbind_chunks <- function(chunks) {
  chunks <- Filter(Negate(is.null), chunks)
  if (length(chunks) == 0L) return(data.frame())
  all_cols <- unique(unlist(lapply(chunks, names), use.names = FALSE))
  padded <- lapply(chunks, function(d) {
    missing_cols <- setdiff(all_cols, names(d))
    for (col in missing_cols) d[[col]] <- NA
    d[, all_cols, drop = FALSE]
  })
  do.call(rbind, padded)
}

#' Batch predict precipitation d2H for multiple sites
#'
#' Processes multiple sites with progress indicators and optional parallelization.
#' Handles large datasets efficiently by processing in chunks.
#'
#' @param data Data frame containing all measurements
#' @param model Model name or "auto" for automatic selection
#' @param chunk_size Number of sites to process at once (default 100)
#' @param parallel Logical whether to use parallel processing
#' @param n_cores Number of cores for parallel processing (NULL for auto)
#' @param progress Logical whether to show progress bar
#' @param return_diagnostics Logical whether to return diagnostic information
#' @param ... Additional arguments passed to predict_d2h_precip
#'
#' @return Data frame with predictions for all sites
#' @export
#' @examples
#' \dontrun{
#' # Load a large dataset
#' large_data <- read.csv("sites.csv")
#'
#' # Process with progress bar
#' results <- batch_predict(large_data, progress = TRUE)
#'
#' # Process in parallel
#' results <- batch_predict(large_data, parallel = TRUE, n_cores = 4)
#'
#' # Process with specific model
#' results <- batch_predict(large_data, model = "baseline_env_sp")
#' }
batch_predict <- function(data,
                         model = "auto",
                         chunk_size = 100,
                         parallel = FALSE,
                         n_cores = NULL,
                         progress = TRUE,
                         return_diagnostics = FALSE,
                         ...) {

  n_sites <- nrow(data)

  if (n_sites == 0) {
    stop("Data frame is empty")
  }

  # For small datasets, just use regular predict
  if (n_sites <= 10) {
    return(predict_d2h_precip(data, model = model, progress = FALSE, ...))
  }

  if (progress) {
    cat("Batch processing", n_sites, "sites\n")
  }

  # Determine chunks
  n_chunks <- ceiling(n_sites / chunk_size)
  chunks <- split(seq_len(n_sites), ceiling(seq_len(n_sites) / chunk_size))

  if (progress) {
    cat("Processing in", n_chunks, "chunks of up to", chunk_size, "sites\n")
  }

  # Process chunks
  if (parallel && n_sites > 100) {
    results <- process_parallel(data, chunks, model, n_cores, progress, ...)
  } else {
    results <- process_sequential(data, chunks, model, progress, ...)
  }

  # Combine results. Use a column-tolerant rbind so a chunk that hit the
  # error-fallback path (smaller column set) does not abort the overall
  # batch with "numbers of columns of arguments do not match".
  combined_results <- .rbind_chunks(results)

  # Add diagnostics if requested
  if (return_diagnostics) {
    attr(combined_results, "diagnostics") <- list(
      n_sites = n_sites,
      n_chunks = n_chunks,
      chunk_size = chunk_size,
      parallel = parallel,
      model_used = if (length(unique(combined_results$model_used)) == 1) {
        unique(combined_results$model_used)
      } else {
        "mixed"
      },
      processing_time = attr(results, "processing_time")
    )
  }

  return(combined_results)
}

#' Process chunks sequentially with progress bar
#'
#' @param data Full dataset
#' @param chunks List of index vectors for chunks
#' @param model Model name
#' @param progress Show progress bar
#' @param ... Additional arguments
#' @return List of results for each chunk
#' @keywords internal
process_sequential <- function(data, chunks, model, progress, ...) {

  n_chunks <- length(chunks)
  results <- vector("list", n_chunks)

  if (progress) {
    pb <- txtProgressBar(min = 0, max = n_chunks, style = 3)
  }

  start_time <- Sys.time()

  for (i in seq_along(chunks)) {
    chunk_indices <- chunks[[i]]
    chunk_data <- data[chunk_indices, , drop = FALSE]

    # Add row identifiers to preserve order
    chunk_data$.row_id <- chunk_indices

    # Process chunk
    tryCatch({
      chunk_results <- predict_d2h_precip(
        chunk_data,
        model = model,
        progress = FALSE,
        verbose = FALSE,
        ...
      )

      # Add row identifiers to results
      chunk_results$.row_id <- chunk_data$.row_id
      results[[i]] <- chunk_results

    }, error = function(e) {
      warning("Error in chunk ", i, ": ", e$message)
      # Return NA results for failed chunk. Column set must match the
      # success path so rbind across chunks does not fail.
      chunk_results <- data.frame(
        d2h_precip_mean = rep(NA, nrow(chunk_data)),
        d2h_precip_median = rep(NA, nrow(chunk_data)),
        d2h_precip_sd = rep(NA, nrow(chunk_data)),
        d2h_precip_lower = rep(NA, nrow(chunk_data)),
        d2h_precip_upper = rep(NA, nrow(chunk_data)),
        prediction_interval_width = rep(NA_real_, nrow(chunk_data)),
        model_used = NA,
        .row_id = chunk_data$.row_id
      )
      results[[i]] <- chunk_results
    })

    if (progress) {
      setTxtProgressBar(pb, i)
    }
  }

  processing_time <- as.numeric(Sys.time() - start_time, units = "secs")

  if (progress) {
    close(pb)
    cat(sprintf("\nCompleted in %.1f seconds (%.1f sites/sec)\n",
                processing_time,
                nrow(data) / processing_time))
  }

  attr(results, "processing_time") <- processing_time
  return(results)
}

#' Process chunks in parallel
#'
#' @param data Full dataset
#' @param chunks List of index vectors for chunks
#' @param model Model name
#' @param n_cores Number of cores
#' @param progress Show progress
#' @param ... Additional arguments
#' @return List of results for each chunk
#' @keywords internal
process_parallel <- function(data, chunks, model, n_cores, progress, ...) {

  # Check for parallel package
  if (!requireNamespace("parallel", quietly = TRUE)) {
    if (progress) {
      cat("Package 'parallel' not available, using sequential processing\n")
    }
    return(process_sequential(data, chunks, model, progress, ...))
  }

  # Determine number of cores
  if (is.null(n_cores)) {
    n_cores <- min(parallel::detectCores() - 1, length(chunks))
    n_cores <- max(1, n_cores)
  }

  if (progress) {
    cat("Using", n_cores, "cores for parallel processing\n")
  }

  start_time <- Sys.time()

  # Create cluster
  cl <- parallel::makeCluster(n_cores)
  on.exit(parallel::stopCluster(cl))

  # Export necessary objects and load package
  parallel::clusterEvalQ(cl, library(leafwax))

  # Process chunks in parallel
  results <- parallel::parLapply(cl, chunks, function(chunk_indices) {
    chunk_data <- data[chunk_indices, , drop = FALSE]
    chunk_data$.row_id <- chunk_indices

    tryCatch({
      chunk_results <- predict_d2h_precip(
        chunk_data,
        model = model,
        progress = FALSE,
        verbose = FALSE,
        ...
      )
      chunk_results$.row_id <- chunk_data$.row_id
      chunk_results
    }, error = function(e) {
      # Return NA results for failed chunk. Column set must match the
      # success path so rbind across chunks does not fail.
      data.frame(
        d2h_precip_mean = rep(NA, nrow(chunk_data)),
        d2h_precip_median = rep(NA, nrow(chunk_data)),
        d2h_precip_sd = rep(NA, nrow(chunk_data)),
        d2h_precip_lower = rep(NA, nrow(chunk_data)),
        d2h_precip_upper = rep(NA, nrow(chunk_data)),
        prediction_interval_width = rep(NA_real_, nrow(chunk_data)),
        model_used = NA,
        .row_id = chunk_data$.row_id
      )
    })
  })

  processing_time <- as.numeric(Sys.time() - start_time, units = "secs")

  if (progress) {
    cat(sprintf("Completed in %.1f seconds (%.1f sites/sec)\n",
                processing_time,
                nrow(data) / processing_time))
  }

  attr(results, "processing_time") <- processing_time
  return(results)
}

#' Compare predictions across multiple models
#'
#' Runs predictions using multiple models and compares results.
#'
#' @param data Data frame with measurements
#' @param models Character vector of model names to compare
#' @param summary_fun Function to summarize across models (default is mean)
#' @param return_all Logical whether to return all model results
#' @param progress Logical whether to show progress
#' @param ... Additional arguments passed to predict_d2h_precip
#'
#' @return Data frame with ensemble predictions or list of all results
#' @export
#' @examples
#' \dontrun{
#' data(example_data)
#'
#' # Compare multiple models
#' comparison <- compare_models(
#'   example_data,
#'   models = c("baseline", "baseline_env", "baseline_sp")
#' )
#'
#' # Get all individual model results
#' all_results <- compare_models(
#'   example_data,
#'   models = c("baseline", "baseline_env"),
#'   return_all = TRUE
#' )
#' }
compare_models <- function(data,
                          models = NULL,
                          summary_fun = mean,
                          return_all = FALSE,
                          progress = TRUE,
                          ...) {

  # Default to a small structurally diverse comparison set rather than
  # all 14 v10 models. Users wanting an exhaustive sweep should pass
  # available_models() explicitly.
  if (is.null(models)) {
    models <- c("baseline", "baseline_sp", "full_sp")
  }

  # Validate `...` against predict_d2h_precip's formals up front. R's
  # tryCatch around the per-model loop would otherwise convert an
  # "unused argument" error from a typo (e.g. `verb = FALSE`) into a
  # silent per-model warning, which then bubbles up as the misleading
  # "All models failed" stop. Catching here gives the user the actual
  # cause. After validation, drop the loop-controlled formals
  # (data/model/progress/verbose) from extra_args so they cannot be
  # supplied twice in the do.call below.
  pdp_formals <- names(formals(predict_d2h_precip))
  extra_args <- list(...)
  if (length(extra_args) > 0L) {
    bad <- setdiff(names(extra_args), pdp_formals)
    if (length(bad) > 0L) {
      pass_through <- setdiff(pdp_formals,
                              c("data", "model", "progress", "verbose"))
      stop("Unknown argument(s) passed via `...`: ",
           paste(sQuote(bad), collapse = ", "),
           ". Valid `...` names for compare_models: ",
           paste(sQuote(pass_through), collapse = ", "), ".")
    }
    extra_args[c("data", "model", "progress", "verbose")] <- NULL
  }

  # Check which models have data available. Bind to a local name that
  # does NOT shadow the exported available_models() function.
  available_df <- list_models(check_data = TRUE, verbose = FALSE)
  models_with_data <- models[models %in% available_df$model[
    available_df$data_status != "Not available"
  ]]

  if (length(models_with_data) == 0) {
    stop("No model data available. Download with download_model_data()")
  }

  if (length(models_with_data) < length(models)) {
    missing <- setdiff(models, models_with_data)
    warning("Skipping models without data: ", paste(missing, collapse = ", "))
    models <- models_with_data
  }

  n_models <- length(models)

  if (progress) {
    cat("Comparing", n_models, "models:", paste(models, collapse = ", "), "\n")
    pb <- txtProgressBar(min = 0, max = n_models, style = 3)
  }

  # Run predictions for each model
  model_results <- list()

  for (i in seq_along(models)) {
    model_name <- models[i]

    if (progress) {
      setTxtProgressBar(pb, i - 0.5)
    }

    tryCatch({
      # `extra_args` was validated above and stripped of the formals
      # that this loop sets explicitly (data, model, progress, verbose).
      results <- do.call(predict_d2h_precip, c(
        list(data = data, model = model_name,
             progress = FALSE, verbose = FALSE),
        extra_args
      ))

      # Store raw per-model results. The per-model column rename is
      # applied below in the return_all = TRUE path; the ensemble
      # summary path needs the original column names to extract the
      # `d2h_precip_mean` / `d2h_precip_median` series uniformly.
      model_results[[model_name]] <- results

    }, error = function(e) {
      warning("Failed to run model ", model_name, ": ", e$message)
    })

    if (progress) {
      setTxtProgressBar(pb, i)
    }
  }

  if (progress) {
    close(pb)
  }

  if (length(model_results) == 0) {
    stop("All models failed")
  }

  # Combine results
  if (return_all) {
    # Return all individual model results. Apply the per-model column
    # rename here so the cbind product carries unambiguous,
    # model-tagged column names.
    rename_cols <- function(df, mname) {
      keep <- names(df) == ".row_id"
      names(df)[!keep] <- paste0(names(df)[!keep], "_", mname)
      df
    }
    combined <- rename_cols(model_results[[1]], names(model_results)[1])
    if (length(model_results) > 1) {
      for (i in 2:length(model_results)) {
        combined <- cbind(
          combined,
          rename_cols(model_results[[i]], names(model_results)[i])
        )
      }
    }
    return(combined)
  } else {
    # Compute ensemble summary
    mean_cols <- grep("mean", names(model_results[[1]]), value = TRUE)
    median_cols <- grep("median", names(model_results[[1]]), value = TRUE)

    # Extract predictions from each model. sapply() returns a vector
    # (no dim) when each model contributes a length-1 prediction; coerce
    # to a 1 x n_models matrix so the row-wise apply() below works for
    # both single-site and multi-site inputs.
    means <- sapply(model_results, function(x) x[[mean_cols[1]]])
    medians <- sapply(model_results, function(x) x[[median_cols[1]]])
    if (is.null(dim(means)))   means   <- matrix(means,   nrow = 1)
    if (is.null(dim(medians))) medians <- matrix(medians, nrow = 1)

    # Compute ensemble statistics. `models_used` reports the models
    # that actually succeeded (`names(model_results)`), not the
    # originally requested set, so partial-failure runs are not
    # silently misreported.
    ensemble_results <- data.frame(
      d2h_precip_ensemble_mean = apply(means, 1, summary_fun, na.rm = TRUE),
      d2h_precip_ensemble_median = apply(medians, 1, summary_fun, na.rm = TRUE),
      d2h_precip_ensemble_sd = apply(means, 1, sd, na.rm = TRUE),
      d2h_precip_ensemble_min = apply(means, 1, min, na.rm = TRUE),
      d2h_precip_ensemble_max = apply(means, 1, max, na.rm = TRUE),
      n_models = apply(means, 1, function(x) sum(!is.na(x))),
      models_used = paste(names(model_results), collapse = ";")
    )

    return(ensemble_results)
  }
}

