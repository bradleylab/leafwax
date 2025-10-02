# R/batch_processing.R - Functions for batch processing with progress indicators

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
#' results <- batch_predict(large_data, model = "b0b1_elev_sp")
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

  # Combine results
  combined_results <- do.call(rbind, results)

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
      # Return NA results for failed chunk
      chunk_results <- data.frame(
        d2h_precip_mean = rep(NA, nrow(chunk_data)),
        d2h_precip_median = rep(NA, nrow(chunk_data)),
        d2h_precip_sd = rep(NA, nrow(chunk_data)),
        d2h_precip_lower = rep(NA, nrow(chunk_data)),
        d2h_precip_upper = rep(NA, nrow(chunk_data)),
        model_used = NA,
        .row_id = chunk_data$.row_id
      )
      results[[i]] <- chunk_results
    })

    if (progress) {
      setTxtProgressBar(pb, i)
    }
  }

  if (progress) {
    close(pb)
    processing_time <- as.numeric(Sys.time() - start_time, units = "secs")
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
      # Return NA results for failed chunk
      data.frame(
        d2h_precip_mean = rep(NA, nrow(chunk_data)),
        d2h_precip_median = rep(NA, nrow(chunk_data)),
        d2h_precip_sd = rep(NA, nrow(chunk_data)),
        d2h_precip_lower = rep(NA, nrow(chunk_data)),
        d2h_precip_upper = rep(NA, nrow(chunk_data)),
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
#'   models = c("b0b1", "b0b1_elev", "b0b1_sp")
#' )
#'
#' # Get all individual model results
#' all_results <- compare_models(
#'   example_data,
#'   models = c("b0b1", "b0b1_elev"),
#'   return_all = TRUE
#' )
#' }
compare_models <- function(data,
                          models = NULL,
                          summary_fun = mean,
                          return_all = FALSE,
                          progress = TRUE,
                          ...) {

  # Default to comparing base, elevation, and spatial models
  if (is.null(models)) {
    models <- c("b0b1", "b0b1_elev", "b0b1_sp", "b0b1_elev_sp")
  }

  # Check which models have data available
  available_models <- list_models(check_data = TRUE, verbose = FALSE)
  models_with_data <- models[models %in% available_models$model[
    available_models$data_status != "Not available"
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
      results <- predict_d2h_precip(
        data,
        model = model_name,
        progress = FALSE,
        verbose = FALSE,
        ...
      )

      # Rename columns to include model name
      names(results)[names(results) != ".row_id"] <- paste0(
        names(results)[names(results) != ".row_id"],
        "_", model_name
      )

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
    # Return all individual model results
    combined <- model_results[[1]]
    if (length(model_results) > 1) {
      for (i in 2:length(model_results)) {
        combined <- cbind(combined, model_results[[i]])
      }
    }
    return(combined)
  } else {
    # Compute ensemble summary
    mean_cols <- grep("mean", names(model_results[[1]]), value = TRUE)
    median_cols <- grep("median", names(model_results[[1]]), value = TRUE)

    # Extract predictions from each model
    means <- sapply(model_results, function(x) x[[mean_cols[1]]])
    medians <- sapply(model_results, function(x) x[[median_cols[1]]])

    # Compute ensemble statistics
    ensemble_results <- data.frame(
      d2h_precip_ensemble_mean = apply(means, 1, summary_fun, na.rm = TRUE),
      d2h_precip_ensemble_median = apply(medians, 1, summary_fun, na.rm = TRUE),
      d2h_precip_ensemble_sd = apply(means, 1, sd, na.rm = TRUE),
      d2h_precip_ensemble_min = apply(means, 1, min, na.rm = TRUE),
      d2h_precip_ensemble_max = apply(means, 1, max, na.rm = TRUE),
      n_models = apply(means, 1, function(x) sum(!is.na(x))),
      models_used = paste(models, collapse = ";")
    )

    return(ensemble_results)
  }
}

#' Monitor memory usage during batch processing
#'
#' Utility function to track memory usage during large batch operations.
#'
#' @param message Optional message to print with memory info
#' @return List with memory statistics
#' @export
monitor_memory <- function(message = NULL) {

  if (!is.null(message)) {
    cat(message, "\n")
  }

  # Get memory info
  mem_used <- as.numeric(utils::object.size(ls(envir = .GlobalEnv))) / 1024^2
  gc_info <- gc()

  mem_stats <- list(
    used_mb = mem_used,
    gc_used_mb = sum(gc_info[, 2]),
    gc_max_mb = sum(gc_info[, 6])
  )

  cat(sprintf("Memory: %.1f MB used, %.1f MB after gc\n",
              mem_stats$used_mb,
              mem_stats$gc_used_mb))

  return(invisible(mem_stats))
}