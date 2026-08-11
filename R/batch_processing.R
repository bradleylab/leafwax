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

#' Jointly invert multiple observations from one record
#'
#' Sends all rows through one joint Bayesian inversion so they coherently
#' reweight the shared calibration draws. Chunked and parallel processing are
#' deliberately disabled because splitting a record changes that joint target.
#'
#' @param data Data frame containing observations from one same-site record. A
#'   `record_id` column is required when there is more than one row.
#' @param model Model name or "auto" for automatic selection
#' @param chunk_size Retained for compatibility and recorded in diagnostics;
#'   it does not split the joint inversion.
#' @param parallel Must be `FALSE`; parallel chunks would change the target.
#' @param n_cores Retained for compatibility and diagnostics.
#' @param progress Logical whether to show progress bar
#' @param return_diagnostics Logical whether to return diagnostic information
#' @param ... Additional arguments passed to predict_d2h_precip
#'
#' @return A `leafwax_inverse` object for the jointly inverted rows.
#' @export
#' @examples
#' \dontrun{
#' local({
#'   old <- options(leafwax.suppress_preview_warning = TRUE)
#'   on.exit(options(old))
#'
#'   data(example_data)
#'   prior <- d2h_prior_normal(mean = -70, sd = 30)
#'   large_data <- example_data[rep(seq_len(nrow(example_data)), length.out = 12), ]
#'   row.names(large_data) <- NULL
#'   large_data$longitude <- large_data$longitude[[1]]
#'   large_data$latitude <- large_data$latitude[[1]]
#'   large_data$record_id <- "example_record"
#'
#'   # Process in chunks
#'   results <- batch_predict(
#'     large_data,
#'     chunk_size = 6,
#'     progress = FALSE,
#'     prior = prior,
#'     verbose = FALSE
#'   )
#'
#'   # Process with a specific model
#'   results <- batch_predict(
#'     large_data,
#'     model = "baseline_sp",
#'     chunk_size = 6,
#'     progress = FALSE,
#'     prior = prior,
#'     verbose = FALSE
#'   )
#' })
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
  if (n_sites == 0L) {
    stop("Data frame is empty")
  }
  if (isTRUE(parallel)) {
    stop(
      "parallel batch inversion is unavailable because splitting rows would ",
      "change the joint calibration-draw posterior.",
      call. = FALSE
    )
  }
  if (progress) {
    message("Jointly inverting ", n_sites, " observations.")
  }
  result <- predict_d2h_precip(
    data = data,
    model = model,
    progress = FALSE,
    verbose = FALSE,
    ...
  )
  if (return_diagnostics) {
    result$diagnostics$batch <- list(
      n_sites = n_sites,
      joint_call = TRUE,
      chunking_disabled = TRUE,
      requested_chunk_size = chunk_size,
      requested_cores = n_cores
    )
  }
  result
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
#' local({
#'   old <- options(leafwax.suppress_preview_warning = TRUE)
#'   on.exit(options(old))
#'
#'   data(example_data)
#'   prior <- d2h_prior_normal(mean = -70, sd = 30)
#'
#'   # Compare multiple models
#'   comparison <- compare_models(
#'     example_data,
#'     models = c("baseline", "baseline_sp"),
#'     prior = prior,
#'     progress = FALSE
#'   )
#'
#'   # Get all individual model results
#'   all_results <- compare_models(
#'     example_data,
#'     models = c("baseline", "baseline_sp"),
#'     prior = prior,
#'     return_all = TRUE,
#'     progress = FALSE
#'   )
#' })
#' }
compare_models <- function(data,
                          models = NULL,
                          summary_fun = mean,
                          return_all = FALSE,
                          progress = TRUE,
                          ...) {

  if (is.null(models)) {
    stop("models must be supplied explicitly; no default scientific comparison is defined.",
         call. = FALSE)
  }
  unsupported <- setdiff(models, .supported_bayesian_inverse_models)
  if (length(unsupported)) {
    stop("Unsupported Bayesian-inversion comparison model(s): ",
         paste(unsupported, collapse = ", "), call. = FALSE)
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
  if (is.null(extra_args$prior)) {
    stop("A proper prior must be supplied explicitly to compare_models().",
         call. = FALSE)
  }
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
    stop(
      "No complete model data available. Install the full posterior archive ",
      "in the package cache or use a validated working checkout."
    )
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
    return(model_results)
  } else {
    # Compute ensemble summary
    means <- sapply(
      model_results,
      function(x) x$summary$d2h_precip_mean
    )
    medians <- sapply(
      model_results,
      function(x) x$summary$d2h_precip_median
    )
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
