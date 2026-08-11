# R/constants.R
#
# Named constants used across the package.

# Default analytical uncertainty on a single delta-2-H wax measurement,
# in per mil. Applied when the caller does not supply d2H_wax_sd.
# Reflects typical instrument repeatability for GC-IRMS leaf-wax delta-2-H
# (~3 per mil), consistent with the values cited in the calibration set.
DEFAULT_WAX_ERR_PERMIL <- 3.0

# Number of spatial knots in the predictive-process approximation. The
# distributed fits use 125 globally distributed Fibonacci-sphere knots. Prediction
# requires their exact saved coordinates; no replacement lattice is accepted.
N_SPATIAL_KNOTS <- 125L
