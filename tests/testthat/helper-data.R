# Helper for tests.
#
# The package ships preview-tier posteriors (100-draw fixtures). Loading them
# warns; inferential functions stop. Tests that require the complete posterior
# call skip_if_preview_posteriors(), while fixture-contract tests may load them.
options(leafwax.suppress_preview_warning = TRUE)
