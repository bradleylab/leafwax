# Archived v0.1.0 tests

These four files target the v0.1.0 API:

- `invert_d2h()` with arguments `d2h_wax`, `d2h_wax_sd`, `n_iterations`,
  rather than v0.2.0's `invert_d2H()` with `d2H_wax`, `d2H_wax_sd`.
- Model names `simple_oipc`, `minimal`, `full_spatial`,
  `baseline_spatial`, etc., rather than the v10 manuscript names
  (`baseline`, `baseline_sp`, `baseline_env_sp`, ...).
- A `list_available_models()` helper that no longer exists.
- A `compare_models()` API that has been folded into
  `invert_d2H_ensemble()`.

They are kept here for reference during the v0.2.0 port. Tests that
should survive get rewritten under `tests/testthat/test-*.R`; the rest
are dropped.

Targets to port (if useful):

- `test-data-management.R` — cache + download semantics. The
  download helpers are still exported; if data-cache management is
  retained for v0.2.0, port the relevant assertions.
- `test-lookup-tables.R` — lookup tables are a v0.1.0 acceleration
  layer; assess whether they should survive v0.2.0 before porting.
- `test-model-loading.R` — partial overlap with `test-v10-posteriors.R`;
  likely no porting needed.
- `test-inversions.R` — core inversion covered by
  `test-v10-posteriors.R`; numerical sanity assertions could be
  extracted into a new `test-inversion-numerics.R`.
