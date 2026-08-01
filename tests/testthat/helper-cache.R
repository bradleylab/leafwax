# Package tests must not depend on or mutate a developer's user-level cache.
options(
  leafwax.cache_dir = file.path(
    tempdir(), paste0("leafwax-test-cache-", Sys.getpid())
  )
)

skip_if_preview_posteriors <- function(model_name = "baseline") {
  location <- leafwax:::resolve_posterior_file(model_name)
  if (!is.null(location) && identical(location$tier, "light")) {
    testthat::skip("Complete calibration posterior not present in source package.")
  }
}
