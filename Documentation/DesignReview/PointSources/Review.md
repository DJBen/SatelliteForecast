# Sky chart point-source review

Branch: `codex/skychart-point-source-rendering`.

Stars and unresolved planets now use compact, softly fading light points. Magnitude is converted to relative flux (`10^(-0.4m)`), then compressed with a square-root logarithmic radius response. This follows the flux / Gaussian point-spread reasoning in [StarryNight's planetarium shader](https://github.com/DJBen/StarryNight/blob/master/Planetarium/Metal/StarShaders.metal), using a lightweight Core Graphics radial profile instead of adding Metal to the chart. It is a legibility-oriented approximation, not a calibrated optical simulation or a representation of planetary angular diameter.

The standard radius is bounded between 0.55 and 3.2 points. Preview scale is 0.75 and detailed scale is 1.35. Faint stars retain a visible minimum footprint but have lower intensity; spectral colors are preserved. Stars and planets share the same rendering helper. Saturn now follows magnitude instead of a fixed radius. Planet symbols are 9 points and sit outside the light core. Labels on the right half face inward to avoid clipping at the horizon. Sun and Moon retain separate resolved-disk rendering. Satellite markers retain their previous radius mapping.

| Object / magnitude | Previous standard radius | New standard radius |
| --- | ---: | ---: |
| Venus, -4.77 | 12.00 pt | 2.59 pt |
| Jupiter, -2.90 | 7.53 pt | 2.30 pt |
| Sirius, -1.46 | 4.35 pt | 2.04 pt |
| Vega, 0.03 | 2.47 pt | 1.73 pt |
| Faint star, 4.50 | 0.45 pt | 0.83 pt |

The radial falloff reaches transparency at 1.8 times the new radius; it is not a solid disk at that size. Venus's visible bright center is therefore much smaller than before.

## Capture coverage

16 dark-mode hosted app screenshots on iPhone 17 Pro Max / iOS 26.5, fixed 402 × 874-point viewport. Five astronomical moments each have standard (338-point chart), compact (210-point chart, symbols, no constellation lines), and dense (magnitude 6, detailed radius mapping) configurations. A sixth year exercises the actual scrollable detailed pass screen with its satellite path and annotations.

| Year | Observer | Condition |
| --- | --- | --- |
| 2020 | Bay Area, 37.49 / -122.23 | Evening Venus, magnitude -4.74, Sun -9°, Venus altitude 29° |
| 2021 | Bay Area | Actual detailed satellite pass screen |
| 2023 | Bay Area | Morning Venus, magnitude -4.77, Sun -9°, Venus altitude 28° |
| 2025 | London, 51.51 / -0.13 | Winter night, Sun -30°, bright planets and Moon |
| 2026 | Bay Area | September dusk, Sun -7°, Venus altitude 7° |
| 2028 | Sydney, -33.87 / 151.21 | Southern winter night, Sun -35° |

Exact UTC times and observer inputs are in [moments.txt](moments.txt). [Review gallery](review-gallery.jpg) contains labeled crops; individual PNGs preserve the complete captures.

## Visual assessment and tuning

- Bright Venus is recognizable without resembling a resolved planetary disk; the recent near-horizon dusk case remains easy to locate.
- Initial dense captures gave faint stars too much equal prominence. Magnitude-dependent intensity now keeps the constellation structure readable while retaining faint stars.
- Compact symbols were enlarged after review, and inward-facing labels fix the clipped Venus name in the 2026 dusk capture.
- The detailed pass screen preserves a clear satellite path, timing annotations, and small colored stars.
- Dense mode intentionally remains busy at phone scale. Nearby bodies can still have overlapping labels (notably Jupiter and the Moon in the 2025 fixture); this change does not implement general label collision avoidance. The Moon's existing broad glow can dominate that particular conjunction.

## Validation and history

`xcodebuildmcp simulator test --scheme SatelliteForecastApp --project-path SatelliteForecast.xcodeproj --simulator-id 5D6FFD0C-6B24-4F95-8E94-B7F3EBD22FDB --extra-args="-only-testing:SatelliteForecastTests/ScreenSnapshotTests/testPointSourceRenderingReview"`

The review test checks bounded, finite, monotonic radii across magnitudes -30 to +30 at all three scales, verifies Venus is above the horizon in the Venus fixtures, and captures the native views. All captures are dark mode. Capture output is isolated in this directory.

A concurrent workspace commit, `9da498e` (release 1.7.1), included the initial rendering implementation and review fixture while this task was running. Subsequent tuning and screenshot evidence remain on the requested branch; the existing release commit was not rewritten.
