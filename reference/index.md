# Package index

## Inversion

Reconstruct d2H_precip from leaf-wax d2H_wax.

- [`invert_d2h()`](https://bradleylab.github.io/leafwax/reference/invert_d2h.md)
  [`invert_d2H()`](https://bradleylab.github.io/leafwax/reference/invert_d2h.md)
  : Invert leaf wax d2H to precipitation d2H
- [`invert_d2H_ensemble()`](https://bradleylab.github.io/leafwax/reference/invert_d2H_ensemble.md)
  : Ensemble predictions across multiple models

## Paleo-record workflow

Within-record sigma_within, slope, change detection, claim taxonomy.

- [`estimate_sigma_within()`](https://bradleylab.github.io/leafwax/reference/estimate_sigma_within.md)
  : Estimate the within-record residual SD of a leaf-wax record
- [`local_effective_slope()`](https://bradleylab.github.io/leafwax/reference/local_effective_slope.md)
  : Local effective slope at a paleo-reconstruction site
- [`estimate_temporal_autocorrelation()`](https://bradleylab.github.io/leafwax/reference/estimate_temporal_autocorrelation.md)
  : Estimate lag-1 temporal autocorrelation
- [`detect_change()`](https://bradleylab.github.io/leafwax/reference/detect_change.md)
  : Within-record d2H_precip change detection
- [`assess_claim()`](https://bradleylab.github.io/leafwax/reference/assess_claim.md)
  : Assess a paleoclimate claim against the leaf-wax taxonomy

## Models

Routing and metadata for the 14 v10 model variants.

- [`available_models()`](https://bradleylab.github.io/leafwax/reference/available_models.md)
  : Get available models
- [`get_all_model_metadata()`](https://bradleylab.github.io/leafwax/reference/get_all_model_metadata.md)
  : Get all model metadata
- [`get_model_info()`](https://bradleylab.github.io/leafwax/reference/get_model_info.md)
  : Get model info
- [`list_models()`](https://bradleylab.github.io/leafwax/reference/list_models.md)
  : List available models with details
- [`load_posteriors()`](https://bradleylab.github.io/leafwax/reference/load_posteriors.md)
  : Load posterior draws for a model
- [`load_model_posteriors()`](https://bradleylab.github.io/leafwax/reference/load_model_posteriors.md)
  : Load model posteriors from package data
- [`select_best_model()`](https://bradleylab.github.io/leafwax/reference/select_best_model.md)
  : Select best model based on available data
- [`select_best_model_from_flags()`](https://bradleylab.github.io/leafwax/reference/select_best_model_from_flags.md)
  : Select best model based on available data

## Datasets

- [`example_data`](https://bradleylab.github.io/leafwax/reference/example_data.md)
  : Example leaf wax hydrogen isotope data
- [`model_metadata`](https://bradleylab.github.io/leafwax/reference/model_metadata.md)
  : Model metadata for the v10 calibration models

## Lower-level / legacy helpers

Internal-style exports retained from v0.1.0 (data caching, lookup
tables, batch processing, validation) and the lower-level invert_d2h()
function. Most users will not call these directly.

- [`invert_d2h()`](https://bradleylab.github.io/leafwax/reference/invert_d2h.md)
  [`invert_d2H()`](https://bradleylab.github.io/leafwax/reference/invert_d2h.md)
  : Invert leaf wax d2H to precipitation d2H
- [`batch_invert_d2h()`](https://bradleylab.github.io/leafwax/reference/batch_invert_d2h.md)
  : Batch inversion for multiple samples
- [`batch_predict()`](https://bradleylab.github.io/leafwax/reference/batch_predict.md)
  : Batch predict precipitation d2H for multiple sites
- [`predict_d2h_precip()`](https://bradleylab.github.io/leafwax/reference/predict_d2h_precip.md)
  : Predict precipitation d2H from leaf wax d2H
- [`validate_inputs()`](https://bradleylab.github.io/leafwax/reference/validate_inputs.md)
  : Validate input data for inversion
- [`validate_model_inputs()`](https://bradleylab.github.io/leafwax/reference/validate_model_inputs.md)
  : Validate inputs for a specific model
- [`validate_lookup_table()`](https://bradleylab.github.io/leafwax/reference/validate_lookup_table.md)
  : Validate lookup table
- [`get_model_parameters()`](https://bradleylab.github.io/leafwax/reference/get_model_parameters.md)
  : Get model parameters
- [`get_model_recommendations()`](https://bradleylab.github.io/leafwax/reference/get_model_recommendations.md)
  : Get model recommendations based on available data
- [`detect_model_capabilities()`](https://bradleylab.github.io/leafwax/reference/detect_model_capabilities.md)
  : Detect model capabilities from model name
- [`list_model_names()`](https://bradleylab.github.io/leafwax/reference/list_model_names.md)
  : List model names
- [`leafwax_config()`](https://bradleylab.github.io/leafwax/reference/leafwax_config.md)
  : Get leafwax configuration
- [`leafwax_set_config()`](https://bradleylab.github.io/leafwax/reference/leafwax_set_config.md)
  : Set leafwax configuration
- [`monitor_memory()`](https://bradleylab.github.io/leafwax/reference/monitor_memory.md)
  : Monitor memory usage during batch processing
- [`benchmark_lookup()`](https://bradleylab.github.io/leafwax/reference/benchmark_lookup.md)
  : Benchmark lookup table vs direct computation
- [`compare_models()`](https://bradleylab.github.io/leafwax/reference/compare_models.md)
  : Compare predictions across multiple models
- [`create_lookup_table()`](https://bradleylab.github.io/leafwax/reference/create_lookup_table.md)
  : Create lookup table for spatial parameters
- [`create_regional_lookup()`](https://bradleylab.github.io/leafwax/reference/create_regional_lookup.md)
  : Create optimized lookup table for region
- [`cache_all_lookup_tables()`](https://bradleylab.github.io/leafwax/reference/cache_all_lookup_tables.md)
  : Cache all lookup tables for available spatial models
- [`use_lookup_if_available()`](https://bradleylab.github.io/leafwax/reference/use_lookup_if_available.md)
  : Use lookup table in inversion (if available)
- [`get_spatial_params()`](https://bradleylab.github.io/leafwax/reference/get_spatial_params.md)
  : Get spatial parameters from lookup table
- [`generate_fibonacci_sphere()`](https://bradleylab.github.io/leafwax/reference/generate_fibonacci_sphere.md)
  : Generate Fibonacci sphere points
- [`generate_global_grid()`](https://bradleylab.github.io/leafwax/reference/generate_global_grid.md)
  : Generate global 1x1 degree grid
- [`predict_spatial_mpp()`](https://bradleylab.github.io/leafwax/reference/predict_spatial_mpp.md)
  : Legacy single-GP predictor – DEPRECATED.
- [`predict_spatial_dual_gp()`](https://bradleylab.github.io/leafwax/reference/predict_spatial_dual_gp.md)
  : Predict both spatial intercept and spatial slope at new locations
- [`predict_one_gp_mpp()`](https://bradleylab.github.io/leafwax/reference/predict_one_gp_mpp.md)
  : Predict an mPP Gaussian-process random effect at a new location
- [`download_model_data()`](https://bradleylab.github.io/leafwax/reference/download_model_data.md)
  : Download model data from GitHub releases
- [`check_data_cache()`](https://bradleylab.github.io/leafwax/reference/check_data_cache.md)
  : Check if model data exists in cache
- [`clear_data_cache()`](https://bradleylab.github.io/leafwax/reference/clear_data_cache.md)
  : Clear model data cache
- [`clear_download_cache()`](https://bradleylab.github.io/leafwax/reference/clear_download_cache.md)
  : Clear download cache
- [`get_cache_dir()`](https://bradleylab.github.io/leafwax/reference/get_cache_dir.md)
  : Get leafwax data cache directory
- [`get_cache_info()`](https://bradleylab.github.io/leafwax/reference/get_cache_info.md)
  : Get cache size information
- [`get_data_path()`](https://bradleylab.github.io/leafwax/reference/get_data_path.md)
  : Get path to data file
- [`get_data_url()`](https://bradleylab.github.io/leafwax/reference/get_data_url.md)
  : Get data download URLs
- [`list_cached_models()`](https://bradleylab.github.io/leafwax/reference/list_cached_models.md)
  : List available models in cache
- [`setup_leafwax_data()`](https://bradleylab.github.io/leafwax/reference/setup_leafwax_data.md)
  : Setup leafwax data management
- [`verify_data_integrity()`](https://bradleylab.github.io/leafwax/reference/verify_data_integrity.md)
  : Verify data integrity
- [`check_model_data()`](https://bradleylab.github.io/leafwax/reference/check_model_data.md)
  : Check if model data exists locally
- [`download_with_progress()`](https://bradleylab.github.io/leafwax/reference/download_with_progress.md)
  : Download file with progress bar
- [`generate_model_description()`](https://bradleylab.github.io/leafwax/reference/generate_model_description.md)
  : Generate human-readable model description
- [`get_cache_files()`](https://bradleylab.github.io/leafwax/reference/get_cache_files.md)
  : Get cache files for a model
- [`get_data_manifest()`](https://bradleylab.github.io/leafwax/reference/get_data_manifest.md)
  : Get data manifest
- [`get_download_files()`](https://bradleylab.github.io/leafwax/reference/get_download_files.md)
  : Get list of files to download for a model
- [`get_model_size_estimate()`](https://bradleylab.github.io/leafwax/reference/get_model_size_estimate.md)
  : Get estimated download size for a model
- [`get_url_config()`](https://bradleylab.github.io/leafwax/reference/get_url_config.md)
  : Get URL configuration
- [`process_parallel()`](https://bradleylab.github.io/leafwax/reference/process_parallel.md)
  : Process chunks in parallel
- [`process_sequential()`](https://bradleylab.github.io/leafwax/reference/process_sequential.md)
  : Process chunks sequentially with progress bar
- [`use_example_data()`](https://bradleylab.github.io/leafwax/reference/use_example_data.md)
  : Use lightweight example data

## Math / GP internals

Numerical kernels and helper functions used by the spatial GP layer.
Documented for completeness; not part of the user-facing API.

- [`matern32()`](https://bradleylab.github.io/leafwax/reference/matern32.md)
  : Matern 3/2 covariance: k(d) = sigma^2 \* (1 + sqrt(3)\*d/rho) \*
  exp(-sqrt(3)\*d/rho)

- [`pair_distances()`](https://bradleylab.github.io/leafwax/reference/pair_distances.md)
  : Pairwise Euclidean distances between two coordinate matrices.

- [`ls_km_to_std()`](https://bradleylab.github.io/leafwax/reference/ls_km_to_std.md)
  :

  Convert ls in km to standardized-coordinate units, matching the v10
  Stan model's `coord_scale_km = mean(coord_scaling) * 111.0` formula.

- [`standardize_coords()`](https://bradleylab.github.io/leafwax/reference/standardize_coords.md)
  : Standardize a coord matrix using the scaling parameters.

- [`print(`*`<leafwax_posterior>`*`)`](https://bradleylab.github.io/leafwax/reference/print.leafwax_posterior.md)
  : Print method for leafwax_posterior

- [`print(`*`<leafwax_lookup_table>`*`)`](https://bradleylab.github.io/leafwax/reference/print.leafwax_lookup_table.md)
  : Print method for lookup tables

## Package

- [`leafwax`](https://bradleylab.github.io/leafwax/reference/leafwax-package.md)
  [`leafwax-package`](https://bradleylab.github.io/leafwax/reference/leafwax-package.md)
  : leafwax: Bayesian Calibration of Leaf Wax Hydrogen Isotope
  Reconstructions
- [`mini_lookup_table`](https://bradleylab.github.io/leafwax/reference/mini_lookup_table.md)
  : Mini lookup table
- [`mini_posteriors`](https://bradleylab.github.io/leafwax/reference/mini_posteriors.md)
  : Mini posterior draws
