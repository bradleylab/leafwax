#' Generate Fibonacci sphere points
#'
#' Generates evenly distributed points on a sphere using the Fibonacci spiral method.
#'
#' @param n_points Number of points to generate
#' @return Matrix with columns "lon" and "lat" in degrees
#' @keywords internal
#' @export
generate_fibonacci_sphere <- function(n_points = 125) {
  golden_angle <- pi * (3.0 - sqrt(5.0))
  knot_coords <- matrix(NA, n_points, 2)

  for (i in 1:n_points) {
    theta <- golden_angle * (i - 1)
    z <- 1 - 2 * (i - 0.5) / n_points
    radius <- sqrt(1 - z^2)

    lat <- asin(z) * 180 / pi
    lon <- (theta %% (2 * pi)) * 180 / pi - 180

    knot_coords[i, ] <- c(lon, lat)
  }

  colnames(knot_coords) <- c("lon", "lat")
  return(knot_coords)
}

#' Locate a posterior .rds file across the three tiers
#'
#' Tries (1) heavy posteriors shipped with the development install,
#' (2) the user cache populated by `download_model_data()`, and
#' (3) the lightweight posteriors that always ship with the package.
#' Returns `NULL` if no file is found.
#'
#' @param model_name Character, model name (e.g. "baseline_sp").
#' @return List with `path` (character) and `tier` ("heavy"/"cache"/"light"),
#'   or `NULL`.
#' @keywords internal
#' @noRd
resolve_posterior_file <- function(model_name) {
  fname <- paste0(model_name, "_posterior.rds")

  # Tier 1: heavy posteriors. Excluded from the CRAN tarball via
  # .Rbuildignore but present on a development install (and visible
  # under devtools::load_all() because it shadows system.file() to
  # the source tree).
  heavy <- system.file("extdata", "posteriors", fname, package = "leafwax")
  if (heavy != "" && file.exists(heavy)) {
    return(list(path = heavy, tier = "heavy"))
  }

  # Tier 2: user cache populated by `download_model_data()`. The
  # downloader writes to <cache>/posteriors/<model>_posterior.rds.
  cache_path <- file.path(get_cache_dir(create = FALSE),
                          "posteriors", fname)
  if (file.exists(cache_path)) {
    return(list(path = cache_path, tier = "cache"))
  }

  # Tier 3: preview posteriors. Always shipped (100-draw fixture).
  # Sufficient for examples, tests, and the vignette to compile, but
  # callers downstream warn loudly that it is not for inference.
  light <- system.file("extdata", "posteriors_light", fname,
                       package = "leafwax")
  if (light != "" && file.exists(light)) {
    return(list(path = light, tier = "light"))
  }

  NULL
}

#' Load posterior draws for a model
#'
#' Loads posterior draws for one of the 14 leafwax v10 models. The
#' function searches three tiers in order:
#'
#' 1. **Heavy** posteriors at `inst/extdata/posteriors/` (1000 draws,
#'    development install only; excluded from the CRAN tarball).
#' 2. **Cache** populated by [download_model_data()] under
#'    [get_cache_dir()].
#' 3. **Preview** posteriors at `inst/extdata/posteriors_light/`. These
#'    are a 100-draw stratified subsample shipped with every install
#'    so examples and tests run offline. They are intended as a
#'    fixture for code-path verification, **not** for inference: tail
#'    probabilities and 95% credible intervals are noisy at this
#'    sample size. The package issues a warning whenever the preview
#'    tier is in use; downstream functions ([invert_d2H()],
#'    [assess_claim()], [detect_change()]) repeat the warning so it is
#'    visible at the call that actually matters.
#'
#' For inference, run [download_model_data()] once to populate the
#' cache and then call `load_posteriors()` again — the cache tier wins
#' over the preview tier and no further downloads are needed.
#'
#' @param model_name Character string specifying the model name.
#' @param n_draws Integer number of posterior draws to use, or `NULL`
#'   for all available. Requesting more draws than are present
#'   silently returns whatever is available (e.g. all 100 from the
#'   preview tier).
#' @param verbose Logical indicating whether to print loading info.
#'
#' @return A `leafwax_posterior` object: a list with `draws`,
#'   `metadata` (including `metadata$tier`, one of "heavy", "cache",
#'   "light"), optional `spatial`, and accessor closures.
#' @export
#' @examples
#' # Load a model (preview tier on a fresh install)
#' model <- load_posteriors("baseline")
#'
#' # Spatial model with limited draws
#' model_fast <- load_posteriors("baseline_sp", n_draws = 50)
load_posteriors <- function(model_name, n_draws = NULL, verbose = TRUE) {

  if (verbose) {
    message("Loading model: ", model_name)
  }

  loc <- resolve_posterior_file(model_name)
  if (is.null(loc)) {
    available <- list_model_names()
    stop("Model '", model_name, "' not found.\n",
         "Available models: ", paste(available, collapse = ", "))
  }
  posterior_file <- loc$path

  # Load posterior draws
  draws <- readRDS(posterior_file)

  if (verbose) {
    message("  Loaded ", nrow(draws), " draws, ", ncol(draws), " parameters")
  }

  # Subset if requested. Use deterministic stratified thinning
  # (evenly spaced indices across all chains) rather than a random
  # sample, so two independent calls with the same model_name and
  # n_draws return the *same* draws subset. This is what allows
  # local_effective_slope(..., n_draws = N) and invert_d2H(...,
  # n_posterior_draws = N, slope = ...) to be paired by position
  # without silent draw-misalignment.
  if (!is.null(n_draws) && n_draws < nrow(draws)) {
    idx <- round(seq.int(1, nrow(draws), length.out = n_draws))
    draws <- draws[idx, , drop = FALSE]
    if (verbose) {
      cat("  Subsampled to", n_draws, "draws (deterministic stratified)\n")
    }
  }

  # Warn after thinning so the reported draw count matches what the
  # caller actually receives.
  if (loc$tier == "light") {
    warn_preview_tier(model_name, nrow(draws))
  }

  # Create metadata. Capability flags are derived from the actual draws
  # column names rather than the model name, because some model names
  # (e.g., `full`, `full_sp`, `full_interact_sp`) include C4/PFT effects
  # without the substrings the older regex looked for. Spatial / interaction
  # flags still come from the name (those are unambiguous in the v10 set).
  param_names <- names(draws)
  metadata <- list(
    model_name = model_name,
    n_draws = nrow(draws),
    n_parameters = ncol(draws),
    parameters = param_names,
    tier = loc$tier,
    has_elevation = any(grepl("^beta_elev", param_names)) ||
                    grepl("(env|elevation|elev)", model_name),
    has_c4        = any(grepl("^beta_c4", param_names)) ||
                    any(grepl("oipc.*c4|c4.*oipc", param_names, ignore.case = TRUE)),
    has_pft       = any(grepl("^beta_(tree|shrub|grass)", param_names)),
    has_gp        = grepl("(^|_)sp$", model_name),
    has_interaction = grepl("interact", model_name) ||
                      any(grepl("oipc.*(tree|shrub|grass|c4)|(tree|shrub|grass|c4).*oipc",
                                param_names, ignore.case = TRUE))
  )

  # Load spatial metadata if needed
  spatial <- NULL
  if (metadata$has_gp) {
    knot_file <- system.file(
      "extdata", "spatial_metadata",
      paste0(model_name, "_knots.rds"),
      package = "leafwax"
    )

    # If package not installed, look in local directory
    if (!file.exists(knot_file) || knot_file == "") {
      local_knot_file <- file.path("inst", "extdata", "spatial_metadata", paste0(model_name, "_knots.rds"))
      if (file.exists(local_knot_file)) {
        knot_file <- local_knot_file
      }
    }

    if (file.exists(knot_file) && knot_file != "") {
      spatial <- list(knot_locs = readRDS(knot_file))
    } else {
      spatial <- list(knot_locs = generate_fibonacci_sphere(125))
    }

    if (verbose) {
      cat("  Loaded", nrow(spatial$knot_locs), "spatial knots\n")
    }
  }

  # Load standardization parameters used during v10 model fitting.
  # All 14 model variants share an identical scaling_params list, so a
  # single shipped file covers every model.
  scaling <- NULL
  scaling_file <- system.file("extdata", "scaling_params.rds",
                              package = "leafwax")
  if (!file.exists(scaling_file) || scaling_file == "") {
    local_scaling <- file.path("inst", "extdata", "scaling_params.rds")
    if (file.exists(local_scaling)) scaling_file <- local_scaling
  }
  if (file.exists(scaling_file) && scaling_file != "") {
    scaling <- readRDS(scaling_file)
    if (verbose) {
      cat("  Loaded standardization parameters (",
          length(scaling) - 1L, " fields)\n", sep = "")
    }
  } else if (verbose) {
    cat("  No scaling_params.rds found; invert_d2H will fall back to placeholder defaults\n")
  }

  # Create model object with helper functions
  model <- structure(
    list(
      draws = draws,
      metadata = metadata,
      spatial = spatial,
      scaling = scaling,

      # Helper function to get base parameters
      get_base_params = function() {
        list(
          beta_0 = if ("beta_0" %in% names(draws)) draws$beta_0 else draws$b0,
          beta_oipc = if ("beta_oipc" %in% names(draws)) draws$beta_oipc else draws$b1,
          sigma = draws$sigma,
          lambda_decay = if ("lambda_decay" %in% names(draws)) draws$lambda_decay else NULL,
          effective_scale_km = if ("effective_scale_km" %in% names(draws)) draws$effective_scale_km else NULL
        )
      },

      # Helper function to get spatial parameters
      get_spatial_params = function() {
        if (!metadata$has_gp) return(NULL)

        z_cols <- grep("^z_.*spatial", names(draws), value = TRUE)
        list(
          z_spatial = if (length(z_cols) > 0) as.matrix(draws[, z_cols]) else NULL,
          sigma_gp = if ("sigma_intercept_spatial" %in% names(draws)) draws$sigma_intercept_spatial else NULL,
          ls_gp = if ("ls_intercept_km" %in% names(draws)) draws$ls_intercept_km else NULL
        )
      },

      # Helper function to get vegetation parameters
      get_vegetation_params = function() {
        if (!metadata$has_c4 && !metadata$has_pft) return(NULL)

        list(
          beta_c4 = if ("beta_c4" %in% names(draws)) draws$beta_c4 else NULL,
          beta_tree = if ("beta_tree" %in% names(draws)) draws$beta_tree else NULL,
          beta_shrub = if ("beta_shrub" %in% names(draws)) draws$beta_shrub else NULL,
          beta_grass = if ("beta_grass" %in% names(draws)) draws$beta_grass else NULL
        )
      },

      # Helper function to get elevation parameters
      get_elevation_params = function() {
        if (!metadata$has_elevation) return(NULL)

        elev_cols <- grep("beta_elev", names(draws), value = TRUE)
        list(
          beta_elev = if ("beta_elev" %in% names(draws)) draws$beta_elev else NULL,
          coefficients = if (length(elev_cols) > 0) as.matrix(draws[, elev_cols]) else NULL
        )
      }
    ),
    class = "leafwax_posterior"
  )

  return(model)
}

#' Print method for leafwax_posterior
#' @param x A leafwax_posterior object
#' @param ... Additional arguments
#' @export
print.leafwax_posterior <- function(x, ...) {
  cat("Leafwax Model:", x$metadata$model_name, "\n")
  cat("Draws:", x$metadata$n_draws, "\n")
  cat("Parameters:", x$metadata$n_parameters, "\n")
  if (x$metadata$has_gp) cat("Spatial: Yes (", nrow(x$spatial$knot_locs), " knots)\n", sep = "")
  if (x$metadata$has_elevation) cat("Elevation: Yes\n")
  if (x$metadata$has_c4) cat("C4 vegetation: Yes\n")
  invisible(x)
}