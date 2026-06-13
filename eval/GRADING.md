# Grading notes (evaluator only — do NOT show to the model under test)

This worktree is a code-fixing benchmark. **Two coupled, subtle algorithmic
defects** were injected into the **deep-space (SDP4 / DeepSDP4) propagator** in
`Frameworks/SatelliteKit`. The model is asked (see `FIX_INSTRUCTIONS.md`) to make
the whole test suite pass by fixing the library source only.

This is the harder successor to an earlier version that injected two *one-token*
defects in the high-level `SatellitePasses` app layer (a closest-approach term in
`hasLineOfSight` and a dropped azimuth sign in the snapshot). Those app-layer
defects have been **removed** — the corresponding source now holds the correct
expressions, and `testLineOfSight` / `ISSPassSydneyTests` pass. The challenge now
lives entirely in the propagator.

## Why it's harder

- The defects are in `DeepSDP4.swift` — ~700 lines of dense luni-solar /
  resonance astrodynamics — with **no dedicated unit test**. They surface only
  through one end-to-end case.
- Localization requires realizing that **only the deep-space code path** is at
  fault: of the five regression satellites, four are near-space (SGP4) and pass;
  only the one with period ≥ 225 min (GPS, ~718 min) routes through SDP4 and fails.
- It is **two coupled defects in two different deep-space functions**
  (`deepSecularEffects` vs `deepPeriodicEffects`), affecting **different physical
  quantities** (along-track secular drift vs cross-track periodic tilt). Fixing
  one does not turn the test green; both must be found.

## The five regression cases (`ReferenceEphemeridesTests`)

| Case | Satellite | NORAD | Regime | Propagator |
|------|-----------|-------|--------|------------|
| 1 | ISS (ZARYA)         | 25544 | LEO, i 51.6°            | SGP4 |
| 2 | NOAA 19             | 33591 | sun-sync, i 99.0°       | SGP4 |
| 3 | HST                 | 20580 | low-incl LEO, i 28.5°   | SGP4 |
| 4 | IRIDIUM 106         | 41917 | near-polar, i 86.4°     | SGP4 |
| 5 | GPS BIIR-5 (PRN 22) | 26407 | deep-space MEO, ~718 min | **SDP4** |

Golden ECI positions + geodetic sub-points were captured from the **reference
(un-patched) propagator** at minutes-after-epoch t = 0, 120, 600. Tolerances:
**0.010 km** in ECI x/y/z, **0.002°** in lat/lon, **0.010 km** in altitude — far
above the ~1e-6 cross-platform libm noise and far below the defect-induced error.

GPS is **non-resonant** (e ≈ 0.012 < 0.5, n ≈ 2.0 rev/day), so it exercises the
luni-solar secular + periodic path (not the resonance integrator). Both injected
defects live on that path, so case 5 fails robustly.

## The injected defects

**Defect D1 — `DeepSDP4.swift`, `deepSecularEffects(...)`**
Secular luni-solar drift of the mean longitude `xll`. The `+=` was flipped to `-=`,
negating the along-track secular rate. Effect grows linearly with time
(0 at t=0, ~0.15 km at t=120, ~0.78 km at t=600 for GPS).
- Correct:  `super.xll   += ssl * mins`
- Injected: `super.xll   -= ssl * mins`

**Defect D2 — `DeepSDP4.swift`, `deepPeriodicEffects(...)`**
Periodic luni-solar perturbation of the inclination `i_new`. The `+=` was flipped
to `-=`, reflecting the cross-track tilt. Effect is present at all times
(~0.1–0.8 km in ECI position for GPS), bounded (does not grow secularly).
- Correct:  `i_new += pinc`
- Injected: `i_new -= pinc`

Both correct forms are inferable by symmetry: each sits among sibling lines that
all use `+=` (`super.Ω += ssh*mins`, `super.ω_new += ssg*mins`, … for D1;
`e_new += pe`, `xll += pl`, `ω_new += pgh` for D2). The difficulty is localizing
them, not guessing a magic constant.

## Start state

`./eval/run_tests.sh` → **13 of 14 pass**, 1 fail:

| Test | Status | Caused by |
|------|--------|-----------|
| `ReferenceEphemeridesTests.testCase5_GPS_DeepSpace` | FAIL | Defect D1 **and** Defect D2 |
| other 13 (incl. cases 1–4, ISS pass, line-of-sight, ground tracks) | pass | — |

## Graded scoring

Both defects break the **same** test method (`testCase5_GPS_DeepSpace`), so the
green count stays **13/14 until both are fixed** — there is no method-level partial
credit. Partial progress is instead visible in the **failure pattern**:

| State | Green | Failing-sample signature of case 5 |
|-------|-------|------------------------------------|
| Start (no fix)         | 13 / 14 | fails at t = 0, 120, 600 |
| Fix D2 only (D1 remains) | 13 / 14 | t=0 now **passes**; t=120, 600 still fail → *time-growing* residual ⇒ a secular term |
| Fix D1 only (D2 remains) | 13 / 14 | fails at t = 0, 120, 600 with steady magnitude → a *periodic* term |
| Fix D1 **and** D2      | 14 / 14 | success |

So a fully correct solution requires repairing **both** the secular and the
periodic deep-space term. A solver that fixes only one can be detected by the
remaining failure signature even though the green count is unchanged.

## Verifying the canonical solution

From the worktree root:

```bash
git apply eval/REFERENCE_SOLUTION.patch   # restores both correct expressions in DeepSDP4
./eval/run_tests.sh                       # => all tests passed
git checkout -- Frameworks/SatelliteKit   # reset to the broken start state
```

## Difficulty

Both are one-token sign flips, but unlike the previous app-layer version they are
buried in deep-space perturbation code with no targeting unit test, require the
solver to deduce that only the SDP4 regime is implicated, and are **coupled** — a
single fix leaves the integration test red. The secular-vs-periodic split makes
D1 (time-growing) and D2 (steady) individually diagnosable from the failure
pattern, but the test only goes green once both are correct.
