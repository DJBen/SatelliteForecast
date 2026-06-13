# Grading notes (evaluator only — do NOT show to the model under test)

This worktree is a code-fixing benchmark. Two independent, subtle algorithmic
defects were injected into `Frameworks/SatellitePasses/Sources`. The model is
asked (see `FIX_INSTRUCTIONS.md`) to make the whole test suite pass by fixing
the source only.

## Start state

`./eval/run_tests.sh` → **7 of 9 pass**, 2 fail:

| Test | Status | Caused by |
|------|--------|-----------|
| `AstroAlgorithmsTests.testLineOfSight` | FAIL | Defect A |
| `ISSPassSydneyTests.testReferencePassMatchesHeavensAbove` | FAIL | Defect A (illumination) **and** Defect B (azimuth) |
| other 7 | pass | — |

## The injected defects

**Defect A — `AstroAlgorithms.swift`, `hasLineOfSight(...)`** (commit `ead1d17`)
The satellite/Sun line-of-sight test compares the closest approach of the
segment P1→P2 to Earth's centre against R⊕. At the foot of the perpendicular,
|Q|² = (1−τ)·|P1|² + τ·(P1·P2). The dot-product term `dotProd` was replaced
with `object2MagSq` (|P2|²), so the occlusion/illumination decision is wrong.
- Correct:  `(1 - τ_min) * object1MagSq + dotProd     * τ_min >= Rₑ * Rₑ`
- Injected: `(1 - τ_min) * object1MagSq + object2MagSq * τ_min >= Rₑ * Rₑ`

**Defect B — `SatelliteInfo+Snapshot.swift`, `topVector2AziEleDst(...)`** (commit `6009c58`)
The SEZ topocentric x-axis points south, so the north-referenced azimuth is
`atan2pi(top.y, -top.x)`. The negation on `top.x` was dropped, reflecting every
azimuth about the E–W axis (e.g. rise 303°→237°, culmination 221°→321°).
- Correct:  `atan2pi(top.y, -top.x) * rad2deg`
- Injected: `atan2pi(top.y,  top.x) * rad2deg`

## Graded scoring (test methods green)

| State | Green | Notes |
|-------|-------|-------|
| Start (no fix) | 7 / 9 | |
| Fix A only | 8 / 9 | `testLineOfSight` recovers; integration test still fails on azimuth |
| Fix B only | 7 / 9 | azimuth recovers but the integration test still fails on illumination (A) |
| Fix A **and** B | 9 / 9 | success |

So a correct, complete fix requires repairing **both** functions; fixing only
`hasLineOfSight` is detectable as partial progress (+1 test).

## Verifying the canonical solution

From the worktree root:

```bash
git apply eval/REFERENCE_SOLUTION.patch   # restores both correct expressions
./eval/run_tests.sh                       # => all tests passed
git checkout -- Frameworks/SatellitePasses/Sources   # reset to the broken start state
```

## Difficulty

Both are one-token edits but require domain reasoning to *fix correctly* rather
than guess: Defect A needs the closest-approach (projection) identity; Defect B
needs the topocentric azimuth convention. Defect B has **no dedicated unit
test** — it can only be localized from the end-to-end pass azimuths — making it
the harder of the two.
