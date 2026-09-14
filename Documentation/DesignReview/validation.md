# Validation

Verified on September 13, 2026.

- StarryNight 3.2.0: all 18 Swift package tests passed.
- StarryNight concurrency suite: all 7 tests passed with Thread Sanitizer enabled,
  with no reported races (`swift test --sanitize=thread --filter CatalogConcurrencyTests`).
- SatelliteForecast: all 6 tests passed on iPhone 17 Pro / iOS 26.5. This includes
  real catalog integration, concurrent snapshot reads, appearance cache separation,
  semantic text/action contrast, buffered launch events and native screenshots.
- Screenshot recording completed for 20 scenarios in both appearances.
- A subsequent comparison-only run passed all 40 image comparisons without
  recording or replacing baselines. No image regions were masked.
- Browser review verified the screen/appearance selectors and wipe comparison.
- `git diff --check` passed.

The test runner uses the committed SwiftPM resolutions and disables automatic
package updates. The reference images are tied to the simulator/runtime noted
above; MapKit tiles remain external content and may change independently.

The `before` set uses the original visual styles after the catalog migration and
fixture corrections. Both versions use the same orbital and star data. Motion
manager injection and the fixed clock correction were also applied to the affected
before captures, so the pass and Sky Now comparisons show the actual screens.

The database lookup benchmark is documented in the StarryNight release README:
500 warm ID queries, five repetitions, median 752.55 ms before indexing versus
2.07 ms after. This does not measure complete app startup or frame rate.
