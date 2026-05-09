# Helper for tests.
#
# The package ships preview-tier posteriors (100-draw fixture) and
# warns whenever they are loaded for inference. Tests run on the
# preview tier by design; suppressing the warning here keeps the
# testthat output focused on actual failures.
options(leafwax.suppress_preview_warning = TRUE)
