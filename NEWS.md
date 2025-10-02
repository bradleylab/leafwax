# leafwax 0.1.0

## Initial CRAN release

### Major features

* **Core functionality**
  - `predict_d2h_precip()`: Main user-facing function for predictions
  - Support for 14 hierarchical Bayesian models
  - Automatic model selection based on available data
  - Full uncertainty quantification with credible intervals

* **Model types**
  - Base models (b0b1)
  - Models with elevation effects
  - Models with C4 vegetation fraction
  - Models with plant functional types (PFT)
  - Spatial models with Gaussian processes
  - Combined models with multiple covariates

* **Data management**
  - Lazy loading system for model data
  - Automatic downloads when needed
  - Lightweight CRAN package (~1 MB)
  - Full posteriors available on demand (~50 MB per model)

* **Performance features**
  - Batch processing for large datasets
  - Progress indicators
  - Parallel processing support
  - Lookup tables for fast spatial predictions

* **Advanced features**
  - Model ensemble predictions
  - Model comparison tools
  - Custom spatial grids
  - Regional lookup tables
  - Full posterior distributions

### Documentation

* Three comprehensive vignettes:
  - Getting Started guide
  - Model Descriptions with theory
  - Advanced Usage examples
* Complete API reference
* pkgdown website
* Extensive examples

### Data

* Example dataset with 10 locations
* Model metadata for all 14 models
* Mini lookup table for demonstrations
* Synthetic posteriors for testing

### Infrastructure

* Full roxygen2 documentation
* Comprehensive test suite
* GitHub Actions CI/CD
* pkgdown website configuration

## Development versions

### 0.0.9000 (pre-release)

* Initial package structure
* Basic inversion functions
* Stan model implementations