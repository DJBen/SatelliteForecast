# Coding task: repair the satellite ephemeris / pass-finding library

## Context

`Frameworks/SatellitePasses` is a small Swift package that computes satellite
**ephemerides** and **observer passes** on top of an SGP4 propagator
(`SatelliteKit`). Given a satellite TLE and an observer's latitude / longitude /
altitude, it produces:

- per-instant **snapshots** (azimuth, elevation, slant range, illumination, …),
- **passes** (rise / culmination / set, illumination changes, visibility),
- satellite **ground tracks**.

The test suite (`Frameworks/SatellitePasses/Tests`) includes an end-to-end test
whose expected numbers were cross-checked against **heavens-above.com** for a
real ISS pass over Sydney on 2026‑06‑14.

## The problem

The library currently has **bugs introduced into the algorithms**. As a result
the test suite is only **partially passing** — some tests fail.

Run the tests to see the current state:

```bash
./eval/run_tests.sh          # native (macOS/Linux) `swift test`
./eval/run_tests.sh --linux  # inside swift:5.9-jammy via Docker/OrbStack (arm64)
```

## Your task

Diagnose and fix the defect(s) **in the library source** so that the **entire
test suite passes**.

Rules:

1. Only edit source files under `Frameworks/SatellitePasses/Sources/` (you may
   read `Frameworks/SatelliteKit` to understand the math it provides).
2. **Do not modify any test** (anything under `*/Tests/`), and do not weaken or
   delete assertions. The tests encode the correct, externally-verified
   behaviour.
3. The bugs are genuine algorithmic / mathematical errors — fix the *math*, do
   not special-case the test inputs.
4. Do **not** read `eval/REFERENCE_SOLUTION.patch`, and do not recover the answer
   from version-control history (`git log`/`git diff` of other branches/commits).

## Success criteria

`./eval/run_tests.sh` reports **all tests passed, 0 failures**.

> Note: `AstroAlgorithmsTests.testSatelliteMagnitude` is wrapped in
> `XCTExpectFailure` on Apple platforms (it documents a known-inaccurate model)
> and is compiled out on Linux — in both cases it counts as passing. You do not
> need to make its inner assertions pass.
