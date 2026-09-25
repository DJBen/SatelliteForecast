# Home Screen pass widgets

Long-press the Home Screen, choose Edit → Add Widget, and search for Space Station
Passes. Long-press an installed widget and choose Edit Widget to configure it.

- Small: **Both stations** shows the next visible ISS and Tiangong passes.
- Small: **Pass chart** shows a simplified elevation arc for the selected station.
- Medium: two station rows with date/time, maximum elevation, and direction. Mini
  arcs are omitted for later dates, active passes, and larger text sizes.
- Large: the earliest visible pass across both stations, with its sampled sky
  trajectory, unlabeled bright stars, planets, and Moon. The time is top right;
  there is no repeated header, maximum-elevation label, or direction footer.

Later-day dates use the locale's short numeric month/day format and local time
conventions; same-day passes show only time. An active pass remains until set.
Content supports English, Spanish, French, Brazilian Portuguese, Russian,
Simplified Chinese, Japanese, and Korean. Widget configuration metadata remains
English. Fixed-size widget typography scales through XXXL; larger accessibility
settings are bounded at XXXL, with complete station/status labels for VoiceOver.

## Shared rendering and data

The app and widget share SkyPassPathRenderer's north-up, east-left projection,
illumination segments, and trajectory arrows. Curvature comes from propagated
positions, sampled about every ten seconds and capped at 121 points per pass.

ForecastService prepares a 560×560 cached sky image with the app's Milky Way
projection and spectral point sources. Stars are above the horizon at culmination,
with magnitude ≤3 and at most 80 included. Mercury, Venus, Mars, Jupiter, and
Saturn use the app's ephemerides, apparent magnitudes, and twilight visibility
policy. The Moon uses MoonAppearance's observer-aware position, phase, orientation,
and texture. No object names or astronomical symbols are drawn. Objects are
clipped to the horizon. The compact twilight gradient remains widget-specific.

Successful real-time forecasts publish both stations atomically to
`group.io.djben.SatelliteForecast`. Visibility requires illuminated elevation
above 10° and Sun elevation below −6°. Location changes invalidate the cache.
Debug time travel and test hosts do not publish fixture data. The extension does
not access the network, propagate orbits, or send telemetry.

Timelines include rise/set transitions and cache expiry. Each entry contains
only the next pass per station. Data expires after 72 hours or the prediction
window, whichever is shorter. Open the forecast screen to refresh it, including
older sky images without the newly added planets and Moon. Missing, expired,
empty, and legacy-cache states provide explicit app-opening guidance.

Both app and extension need the App Group entitlement in distribution profiles.

## Validation

The app and embedded extension built and the app relaunched on iPhone 17 Pro Max
/ iOS 27 in dark mode. All 41 targeted tests passed, including orbital samples,
projection agreement, cache compatibility, star selection, planet horizon/twilight
rules, and native widget previews.

The locale matrix renders 912 cases across eight languages. It covers six
populated layout/station variants at default and XXXL text in four frame profiles,
AX5 at the compact profile, and active/empty/setup/expired/legacy states at all
three text settings. Dimensions in points:

| Profile | Small | Medium | Large |
| --- | --- | --- | --- |
| Compact | 146×146 | 292×146 | 292×311 |
| Narrow | 158×158 | 338×158 | 338×354 |
| Regular | 170×170 | 364×170 | 364×382 |
| Wide | 180×180 | 382×180 | 382×402 |

Cards render without clipping into a transparent gutter; the test rejects pixels
outside the widget bounds with a one-point border tolerance. All 912 cases pass.
Visual review and an OCR scan of all 112 locale contact sheets caught and helped
resolve truncation; the final OCR scan has no ellipsis flags. OCR and bounds checks
do not prove the absence of all overlap or translation issues.

These are native SwiftUI content previews, not installed Home Screen screenshots.
Home Screen placement and Edit Widget interaction remain unverified: the installed
XcodeBuildMCP accessibility helper expects a removed SimulatorKit path, and Device
Hub accessibility requests timed out.

- [Locale/size review gallery](WidgetPreviews/2026-09-25-locales-final/README.md)
- [Large chart with planets and Moon](WidgetPreviews/2026-09-25-planets-moon/large-sky-chart.png)
- [Latest test results](WidgetPreviews/2026-09-25-planets-moon/tests.log)

To reproduce, choose a new evidence directory:

```sh
python3 scripts/capture-widget-previews.py --simulator SIMULATOR_UDID --output /absolute/path/to/new-evidence
swift scripts/review-widget-text.swift /absolute/path/to/new-evidence/locale-matrix
```

The capture script sets dark appearance and restores the test plan afterward.
