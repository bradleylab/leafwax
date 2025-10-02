# data-raw Directory

This directory contains scripts used to prepare the lightweight datasets included with the leafwax package.

## Files

- `prepare_package_data.R` - Main script to generate all package datasets
- `copy_posteriors.R` - Script to copy posterior draws from Stan output (moved from package root)
- `subset_and_organize_data.R` - Script to subset full posteriors for package distribution

## Generating Package Data

To regenerate the lightweight datasets in the `data/` directory:

```r
setwd("data-raw")
source("prepare_package_data.R")
```

This creates:
- `example_data.rda` - Sample dataset with 10 locations
- `model_metadata.rda` - Specifications for all 14 models
- `mini_lookup_table.rda` - Small lookup table for examples (25 grid cells)
- `mini_posteriors.rda` - Synthetic posteriors for b0b1 model (100 draws)

## Data Size

Total size of package data: ~14 KB (compressed)

This keeps the package well under CRAN's size limits while providing functional examples.

## Full Data

Full posterior distributions and high-resolution lookup tables are available via download:

```r
library(leafwax)
download_model_data("b0b1_sp", "standard")  # 2000 draws
download_model_data("b0b1_sp", "full")      # All draws
```

## Note

The files in this directory are not included in the built package (via .Rbuildignore).