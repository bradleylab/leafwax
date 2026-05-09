# Package index

## Inversion

Reconstruct d2H_precip from leaf-wax d2H_wax.

- [`invert_d2h()`](https://bradleylab.github.io/leafwax/reference/invert_d2h.md)
  [`invert_d2H()`](https://bradleylab.github.io/leafwax/reference/invert_d2h.md)
  : Invert leaf wax d2H to precipitation d2H
- [`invert_d2H_ensemble()`](https://bradleylab.github.io/leafwax/reference/invert_d2H_ensemble.md)
  : Ensemble predictions across multiple models

## Paleo-record workflow

Local slope, change detection, claim taxonomy.

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
- [`select_best_model_from_flags()`](https://bradleylab.github.io/leafwax/reference/select_best_model_from_flags.md)
  : Select best model based on available data

## Datasets

- [`example_data`](https://bradleylab.github.io/leafwax/reference/example_data.md)
  : Example leaf wax hydrogen isotope data

## Lower-level helpers

Internal-style exports (data caching, batch processing, validation) and
the lower-level invert_d2h() function. Most users will not call these
directly.

- [`invert_d2h()`](https://bradleylab.github.io/leafwax/reference/invert_d2h.md)
  [`invert_d2H()`](https://bradleylab.github.io/leafwax/reference/invert_d2h.md)
  : Invert leaf wax d2H to precipitation d2H
- [`batch_predict()`](https://bradleylab.github.io/leafwax/reference/batch_predict.md)
  : Batch predict precipitation d2H for multiple sites
- [`predict_d2h_precip()`](https://bradleylab.github.io/leafwax/reference/predict_d2h_precip.md)
  : Predict precipitation d2H from leaf wax d2H
- [`validate_inputs()`](https://bradleylab.github.io/leafwax/reference/validate_inputs.md)
  : Validate input data for inversion
- [`validate_model_inputs()`](https://bradleylab.github.io/leafwax/reference/validate_model_inputs.md)
  : Validate inputs for a specific model
- [`get_model_parameters()`](https://bradleylab.github.io/leafwax/reference/get_model_parameters.md)
  : Get model parameters
- [`detect_model_capabilities()`](https://bradleylab.github.io/leafwax/reference/detect_model_capabilities.md)
  : Detect model capabilities from model name
- [`list_model_names()`](https://bradleylab.github.io/leafwax/reference/list_model_names.md)
  : List model names
- [`leafwax_config()`](https://bradleylab.github.io/leafwax/reference/leafwax_config.md)
  : Get leafwax configuration
- [`leafwax_set_config()`](https://bradleylab.github.io/leafwax/reference/leafwax_set_config.md)
  : Set leafwax configuration
- [`compare_models()`](https://bradleylab.github.io/leafwax/reference/compare_models.md)
  : Compare predictions across multiple models
- [`generate_fibonacci_sphere()`](https://bradleylab.github.io/leafwax/reference/generate_fibonacci_sphere.md)
  : Generate Fibonacci sphere points
- [`predict_spatial_dual_gp()`](https://bradleylab.github.io/leafwax/reference/predict_spatial_dual_gp.md)
  : Predict both spatial intercept and spatial slope at new locations
- [`predict_one_gp_mpp()`](https://bradleylab.github.io/leafwax/reference/predict_one_gp_mpp.md)
  : Predict an mPP Gaussian-process random effect at a new location
- [`download_model_data()`](https://bradleylab.github.io/leafwax/reference/download_model_data.md)
  : Download model data from GitHub releases
- [`check_data_cache()`](https://bradleylab.github.io/leafwax/reference/check_data_cache.md)
  : Check if model data exists in cache
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
- [`download_with_progress()`](https://bradleylab.github.io/leafwax/reference/download_with_progress.md)
  : Download file with progress bar
- [`generate_model_description()`](https://bradleylab.github.io/leafwax/reference/generate_model_description.md)
  : Generate human-readable model description
- [`get_cache_files()`](https://bradleylab.github.io/leafwax/reference/get_cache_files.md)
  : Get cache files for a model
- [`get_data_manifest()`](https://bradleylab.github.io/leafwax/reference/get_data_manifest.md)
  : Get data manifest
- [`get_url_config()`](https://bradleylab.github.io/leafwax/reference/get_url_config.md)
  : Get URL configuration
- [`process_parallel()`](https://bradleylab.github.io/leafwax/reference/process_parallel.md)
  : Process chunks in parallel
- [`process_sequential()`](https://bradleylab.github.io/leafwax/reference/process_sequential.md)
  : Process chunks sequentially with progress bar

## S3 print methods

Pretty-printing for the package’s own S3 classes.

- [`print(`*`<leafwax_posterior>`*`)`](https://bradleylab.github.io/leafwax/reference/print.leafwax_posterior.md)
  : Print method for leafwax_posterior

## Package

- [`leafwax`](https://bradleylab.github.io/leafwax/reference/leafwax-package.md)
  [`leafwax-package`](https://bradleylab.github.io/leafwax/reference/leafwax-package.md)
  : leafwax: Bayesian Calibration of Leaf Wax Hydrogen Isotope
  Reconstructions
