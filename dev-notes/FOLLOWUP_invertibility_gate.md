# Follow-up: principled invertibility gate for the wax→precip inversion

**Status:** OPEN. **Release gating:** blocks the *package* release to users (Zenodo
archive + CRAN), NOT the manuscript / data deposit / analysis-code deposits. The
manuscript reports no numerical reconstructions, so this does not affect it.

**Surfaced:** 2026-07-31, during the chordal-deposit test pass. Reviewed with grok
(codex out of credits). This documents a real statistical limitation and the agreed
proper fix so the current test-greening does not bury it.

## The problem

The inversion reconstructs precipitation δ²H from leaf-wax δ²H by, per posterior
draw, dividing by the local effective slope:

    dD_precip^(s) = ( dD_wax − beta_0(x)^(s) − … ) / slope(x)^(s)

`slope(x)` carries a spatial GP (dual-GP: intercept GP + slope GP). At data-sparse /
domain-edge sites the slope posterior is **not bounded away from zero**. Example at
(lon −90, lat 38), `baseline_sp`, 1000 draws: P(slope>0) ≈ 0.979, 95% lower ≈ 0.01,
median +0.49, ~2.1% of draws < 0.

This is the classical **inverse-calibration / ratio problem**. Dividing by a
denominator whose posterior sits near zero yields heavy, Cauchy-like tails with no
finite mean (Marsaglia 1965), and — by theorem — no finite interval has guaranteed
coverage when the denominator is not bounded from zero (Gleser & Hwang 1987; Fieller
1954; Creasy 1954; Osborne 1991; Brown 1993).

**The real diagnostic is separation from zero, NOT the negative fraction.** A site
that is 100% positive but whose lower quantile hugs zero is just as broken (near-zero
*positive* draws explode the ratio). The current shipped tool only forbids
`slope ≤ 0`, so such sites currently pass and ship overconfident prediction
intervals — a latent issue independent of the chordal change (great-circle had it too).

## Current behavior (interim, shipped now)

There are TWO inversion paths, and only one is guarded:

- **`slope=` override path** (caller passes a slope vector, e.g. from
  `local_effective_slope()`): `invert_d2h()` hard-errors if any per-draw slope is
  ≤ 0 or near zero ("slope must be positive; got at least one negative value").
- **Default path** (no `slope=`): the effective slope is `beta_d2Hp + slope_GP`
  per draw, and there is **NO sign / near-zero guard**. At a site like (-90, 38)
  the default inversion **completes** and ships a heavy-tailed reconstruction
  (verified: `test-phase-c.R` inverts there via the default path and succeeds).

So the current tool does NOT refuse ill-conditioned sites in general — it only
rejects an explicit negative/near-zero `slope=` override. The default reconstruction
that most users hit is unguarded. That is exactly the gap the gate must close, and
it reacts to the wrong statistic (sample minimum) even on the override path — it does
nothing about near-zero *positive* slopes, which are equally unstable.

The override guard is pinned by `tests/testthat/test-phase-b.R` ::
"invert_d2H refuses a negative slope vector supplied via the slope= override".
That test is the regression anchor for the OVERRIDE path only, and MUST be updated
when the gate lands.

## Agreed fix (to implement before package ship)

A per-site **invertibility gate** on separation from zero, plus honest reporting:

1. From the slope draws compute `p_pos = mean(slope > 0)` and
   `q_lo = quantile(slope, α)` (α = 0.025 for a 95% product).
2. **Refuse** (structured status, not crash) unless `p_pos ≥ τ` (τ ∈ {0.99, 0.995})
   **and** `q_lo ≥ δ`. Return `p_pos`, `q_lo`, `δ`, `τ` in the payload.
3. If it passes: reconstruct from positive-slope draws, summarize with
   **median + quantile PI (never mean±sd)**, and report `p_pos`, `q_lo`, and any
   drop fraction.
4. Never clamp/floor the slope. Never silently drop.
5. API status: `invertible` → summaries + diagnostics; `not_invertible` → refuse with
   diagnostics; user-supplied scalar slope ≤ 0 → keep the current hard reject.

**OPEN DECISION — δ (do NOT invent it):** δ is the minimum defensible transfer slope.
Options: (a) a literature-backed minimum wax→precip slope, or (b) a pre-registered
numerical-stability floor justified by a sensitivity analysis. Must be chosen with the
operator and documented; δ = 0 is not acceptable.

## Cleaner upstream alternative (larger)

If the science requires `slope(x) > 0` everywhere, enforce it in the calibration model
(truncated / softplus / log-GP on the slope) and re-fit. This is the clean Bayesian
fix but a major undertaking (new run, new fixtures, full re-verify) — almost certainly
post-submission. The downstream gate must not invent positivity the model did not
enforce.

## References

Fieller (1954); Creasy (1954); Marsaglia (1965); Gleser & Hwang (1987);
Osborne (1991), *Statistical calibration: a review*; Brown (1993),
*Measurement, Regression, and Calibration*.
