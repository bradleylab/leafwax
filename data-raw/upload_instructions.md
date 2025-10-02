# Upload Instructions for leafwax External Data

This document provides step-by-step instructions for uploading the prepared model data to GitHub releases for distribution with the leafwax package.

## Overview

The leafwax package uses a lazy loading system where large model data files are hosted externally and downloaded on demand. This keeps the CRAN package small (~1-2 MB) while allowing users to access full model posteriors and lookup tables (~285 MB total) when needed.

## Files to Upload

After running `prepare_external_data.R`, you will have the following directory structure in `data-raw/external_data_prepared/`:

```
external_data_prepared/
├── manifest.json           # Manifest with checksums and metadata
├── file_list.csv          # List of all files with sizes
├── posteriors/            # Model posterior draws
│   ├── b0b1_posteriors.rds
│   ├── b0b1_elev_posteriors.rds
│   └── ... (one for each model)
├── metadata/              # Model metadata files
│   ├── b0b1_metadata.rds
│   ├── b0b1_elev_metadata.rds
│   └── ... (one for each model)
└── lookup_tables/         # Pre-computed spatial grids
    ├── b0b1_sp_lookup.rds
    ├── b0b1_elev_sp_lookup.rds
    └── ... (only for spatial models)
```

## Step 1: Create GitHub Repository

1. Create a new repository named `leafwax-data` on GitHub
2. Make it public (required for unauthenticated downloads)
3. Add a README explaining this is data for the leafwax R package

Example repository: `https://github.com/[YOUR-USERNAME]/leafwax-data`

## Step 2: Create GitHub Release

1. Go to your repository's releases page: `https://github.com/[YOUR-USERNAME]/leafwax-data/releases`
2. Click "Create a new release"
3. Set the tag version to `v1.0.0`
4. Set the release title to "leafwax Model Data v1.0.0"
5. Add description:

```markdown
## leafwax Model Data Release v1.0.0

This release contains posterior draws and lookup tables for all models in the leafwax R package.

### Contents
- **Posterior draws**: 5000 MCMC samples for each model
- **Model metadata**: Configuration and parameter information
- **Lookup tables**: Pre-computed 1x1 degree spatial grids for GP models
- **Manifest**: File checksums for integrity verification

### File Structure
- `posteriors/`: Model posterior draws (.rds files)
- `metadata/`: Model metadata (.rds files)
- `lookup_tables/`: Spatial lookup tables (.rds files)
- `manifest.json`: File manifest with checksums

### Total Size
~285 MB (compressed)

### Usage
These files are automatically downloaded by the leafwax R package when needed.
```

## Step 3: Upload Files

### Option A: Via GitHub Web Interface (for smaller files)

1. Drag and drop files into the release assets area
2. Upload in batches if needed (GitHub has a 25 MB limit per file via web)
3. Upload the manifest.json file last

### Option B: Via GitHub CLI (recommended for all files)

```bash
# Install GitHub CLI if not already installed
# https://cli.github.com/

# Navigate to your prepared data directory
cd data-raw/external_data_prepared

# Create release and upload all files
gh release create v1.0.0 \
  --repo [YOUR-USERNAME]/leafwax-data \
  --title "leafwax Model Data v1.0.0" \
  --notes-file release_notes.md \
  posteriors/*.rds \
  metadata/*.rds \
  lookup_tables/*.rds \
  manifest.json
```

### Option C: Via Git LFS (for version control of large files)

```bash
# Initialize Git LFS in the repository
git lfs track "*.rds"
git add .gitattributes

# Add and commit files
git add posteriors/ metadata/ lookup_tables/ manifest.json
git commit -m "Add model data files"
git push

# Then create release as in Option A
```

## Step 4: Update Package URLs

After uploading, update the URLs in the leafwax package:

1. Edit `inst/extdata/data_urls.json`:
   - Replace `[YOUR-USERNAME]` with your GitHub username
   - Update URLs to point to your release

2. Example:
```json
{
  "base_url_latest": "https://github.com/bradleylab/leafwax-data/releases/latest/download",
  "base_url_version": "https://github.com/bradleylab/leafwax-data/releases/download/{version}",
  "manifest_url": "https://github.com/bradleylab/leafwax-data/releases/latest/download/manifest.json"
}
```

## Step 5: Test Downloads

Test that downloads work correctly:

```r
library(leafwax)

# Test manual download
download_model_data("b0b1_sp", verbose = TRUE)

# Test automatic download prompt
result <- invert_d2h(
  d2h_wax = -150,
  longitude = -105,
  latitude = 40,
  model_name = "b0b1_sp"
)

# Verify checksums
verify_data_integrity(
  file.path(get_cache_dir(), "posteriors/b0b1_sp_posteriors.rds")
)
```

## Alternative Hosting Options

### Zenodo (Recommended for DOI)

1. Upload to Zenodo for permanent archiving and DOI
2. Link your GitHub repository to Zenodo
3. Zenodo will automatically archive each release
4. Update URLs to use Zenodo links:
```
https://zenodo.org/record/[RECORD-ID]/files/[FILENAME]
```

### Figshare

1. Create dataset on Figshare
2. Upload all RDS files
3. Publish to get DOI
4. Update URLs to use Figshare links:
```
https://figshare.com/ndownloader/files/[FILE-ID]
```

### OSF (Open Science Framework)

1. Create OSF project
2. Upload files to storage
3. Make project public
4. Update URLs to use OSF links:
```
https://osf.io/download/[FILE-ID]/
```

## Updating Data (Future Releases)

When updating model data:

1. Increment version number (e.g., v1.1.0)
2. Run `prepare_external_data.R` with new data
3. Create new GitHub release with updated files
4. Update `data_urls.json` if URL structure changes
5. Update package version and NEWS.md

## File Size Optimization

To reduce file sizes:

1. Use maximum compression when saving RDS files:
```r
saveRDS(object, file, compress = "xz", version = 2)
```

2. Consider splitting very large files:
```r
# Split lookup tables by region
saveRDS(lookup_north_america, "lookup_na.rds", compress = "xz")
saveRDS(lookup_europe, "lookup_eu.rds", compress = "xz")
```

3. Use binary formats for numerical matrices:
```r
# Save as HDF5 for better compression of large matrices
library(rhdf5)
h5write(matrix_data, "data.h5", "dataset_name")
```

## Verification Checklist

Before announcing the data release:

- [ ] All files uploaded successfully
- [ ] manifest.json includes all files with correct checksums
- [ ] URLs in package updated and committed
- [ ] Test download works from clean R session
- [ ] Checksums verify correctly after download
- [ ] Package passes R CMD check with external data
- [ ] Documentation updated with data availability
- [ ] Release notes describe data contents

## Support

If you encounter issues:

1. Check GitHub release asset URLs are public
2. Verify file permissions (must be readable)
3. Test with `curl` or `wget` directly
4. Check firewall/proxy settings
5. Report issues at: https://github.com/[YOUR-USERNAME]/leafwax/issues

## License

Ensure data files are distributed under an appropriate license (same as package or CC-BY).