# Coding task: repair the satellite ephemeris / pass-finding library

## Context

`Frameworks/SatellitePasses` is a Swift package that computes satellite
**ephemerides** and **observer passes**. It sits on top of `Frameworks/SatelliteKit`,
a self-contained SGP4 / SDP4 orbital propagator (the standard NORAD model: a
**near-space** path, SGP4, for orbits with period < 225 min, and a **deep-space**
path, SDP4 / DeepSDP4, with luni-solar and resonance terms for everything else).

Given a satellite TLE and an observer's latitude / longitude / altitude, the stack
produces:

- per-instant **snapshots** (azimuth, elevation, slant range, illumination, …),
- **passes** (rise / culmination / set, illumination changes, visibility),
- satellite **ground tracks**,
- raw Earth-Centered-Inertial **position / velocity** from the propagator.

The test suite (`Frameworks/SatellitePasses/Tests`) includes:

- `ISSPassSydneyTests` — an end-to-end pass whose expected numbers were
  cross-checked against **heavens-above.com** for a real ISS pass over Sydney.
- `ReferenceEphemeridesTests` — a propagator regression suite that propagates
  **five real satellites** (TLEs from celestrak.org) spanning the near-space and
  deep-space regimes and checks their ECI positions and geodetic sub-points
  against reference values.
- `ElementsGroundTrackTests`, `AstroAlgorithmsTests` — ground-track and
  astronomy-helper checks.

## The problem

The library has **bugs introduced into the algorithms**. As a result the test
suite is only **partially passing** — at least one test fails.

Run the tests to see the current state:

```bash
./eval/run_tests.sh          # native (macOS/Linux) `swift test`
./eval/run_tests.sh --linux  # inside swift:5.9-jammy via Docker/OrbStack (arm64)
```

## Your task

Diagnose and fix the defect(s) **in the library source** so that the **entire
test suite passes**.

Rules:

1. You may edit source files under `Frameworks/SatelliteKit/Classes/` and
   `Frameworks/SatellitePasses/Sources/`. Do not edit package manifests, the
   propagator's public API signatures, or anything outside those two source trees.
2. **Do not modify any test** (anything under `*/Tests/`), and do not weaken or
   delete assertions. The tests encode the correct, reference behaviour.
3. The bugs are genuine algorithmic / mathematical errors — fix the *math*, do
   not special-case the test inputs, and do not clamp / post-process outputs to
   sneak past a tolerance.
4. Do **not** read `eval/REFERENCE_SOLUTION.patch` or `eval/GRADING.md`, and do
   not recover the answer from version-control history (`git log` / `git diff` of
   other branches or commits).

## Success criteria

`./eval/run_tests.sh` reports **all tests passed, 0 failures**.

> Note: `AstroAlgorithmsTests.testSatelliteMagnitude` is wrapped in
> `XCTExpectFailure` on Apple platforms (it documents a known-inaccurate model)
> and is compiled out on Linux — in both cases it counts as passing. You do not
> need to make its inner assertions pass.
