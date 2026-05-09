# R/constants.R
#
# Named constants used across the package. Values are scientific
# defaults (analytical uncertainty, knot count, placeholder scaling)
# that have meaning beyond their numeric value, so they live here
# rather than as bare literals at the call site.

# Default analytical uncertainty on a single delta-2-H wax measurement,
# in per mil. Applied when the caller does not supply d2H_wax_sd.
# Reflects typical instrument repeatability for GC-IRMS leaf-wax delta-2-H
# (~3 per mil), consistent with the values cited in the calibration set.
DEFAULT_WAX_ERR_PERMIL <- 3.0

# Number of spatial knots in the predictive-process approximation. The
# v10 fits use 125 globally distributed Fibonacci-sphere knots; spatial
# models loaded without a knot file fall back to a freshly generated
# 125-knot sphere with a warning (load_posteriors() handles the fall).
N_SPATIAL_KNOTS <- 125L

# Defaults for missing covariates in the inversion linear predictor.
# v10 fitted on c4_percent (0-100 scale) with c4_mean = 25, so 25 is
# the predictor's calibration mean (no enrichment / no impoverishment).
# PFT defaults split evenly across tree / shrub / grass with the
# trailing class absorbing the rounding so the three sum to exactly 1.
DEFAULT_C4_PERCENT  <- 25
DEFAULT_PFT_TREE    <- 0.33
DEFAULT_PFT_SHRUB   <- 0.33
DEFAULT_PFT_GRASS   <- 0.34

# Placeholder scaling parameters. Used when load_posteriors() cannot
# find scaling_params.rds. These are NOT the v10 fitted scales — they
# are conservative round numbers intended to keep the inversion
# numerically stable while load_posteriors() emits a loud warning. Do
# not rely on them for inference.
PLACEHOLDER_SCALING <- list(
  d2H_mean  = -200, d2H_sd  = 50,
  oipc_mean =  -50, oipc_sd = 50,
  c4_mean   =   25, c4_sd   = 25,
  lon_mean  =    0, lon_sd  = 90,
  lat_mean  =    0, lat_sd  = 45,
  elev_mean = 1000, elev_sd = 1000
)
