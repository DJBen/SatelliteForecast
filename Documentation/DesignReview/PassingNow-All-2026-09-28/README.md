# Passing now: full active catalog and deferred propagation

The sheet has an explicit content heading and count, visible at both sheet
sizes and when the list is empty. `sheet-dark.png` was reviewed on the iPhone
17 Pro Max / iOS 27 simulator in dark mode. The screenshot uses the existing
historical ISS fixture, not a current full-catalog count.

Sky Now loads the upstream active catalog without a brightness/count cap or
orbit-altitude restriction. Successfully propagated objects above the geometric
horizon appear whether sunlit or shadowed. This includes higher orbits; it does
not include inactive/debris objects absent from the upstream active catalog.

## Scheduling

The initial sweep samples every catalog candidate. For a below-horizon object,
`-range * sin(elevation)` is its distance below the observer's horizon plane.
We bound approach speed using 12 km/s, above Earth-surface escape speed for
Earth-bound satellites, plus Earth rotation times a conservative geocentric
radius bound (including five minutes of possible travel). The scheduled delay
is 80% of distance/speed minus one second, capped at five minutes. Within one
degree of the horizon and above it, checks run at the half-second UI cadence.
This is deliberately an early recheck estimate, not an exact next-rise prediction.

The B-tree extracts only due candidates, including exact-deadline entries.
Replacing those entries avoids duplicates. Empty batches do no propagation;
display updates merge only the visible and updated subsets rather than walking
the full scheduling tree. Existing location, catalog, lifecycle and clock-change
invalidation remains in force.

## Validation

- Simulator build and run succeeded after app changes.
- ForecastTests plus the visual test ran 58 checks: 56 passed initially. Two test
  fixtures still assumed the former catalog (one expected-ID assertion, one disk
  filename); both passed after correction in a targeted two-test rerun.
- Dense independent one-second SGP4 samples cover two hours at three observers,
  including equatorial and high-latitude/elevated locations. Every sampled
  below-horizon recheck window remained below the horizon; over 100 cases deferred
  for more than 30 seconds. This tests the existing LEO fixture, not every orbit.
- A 200-satellite queue regression confirms zero work before the first deadline,
  only two candidates at that exact deadline, no duplicated scheduled entries,
  and a fresh full sweep after a backward clock jump.
- Catalog tests verify 150 candidates remain uncapped and a higher-orbit fixture
  survives loading. Cache freshness, reuse, cancellation and location changes
  retain coverage.
- The device Debug build succeeded. Analytics boundaries/count semantics are
  documented in Analytics.md; no per-satellite telemetry was added.

The updated Debug app was installed on the connected iPhone. Automatic launch
was denied because the phone was locked; the normal simulator app was relaunched.

## Compact header refinement

Replaced the separate content heading with the native inline navigation title
and subtitle. Passing now and Done share the navigation row; the count sits
directly below the title. Removed the extra header block and padding. Reviewed
`compact-sheet-dark.png` on the dark iPhone 17 Pro Max simulator. Simulator and
device builds succeeded. This layout adjustment changes no analytics semantics.

## Sheet filters

Added a filter menu immediately beside Done. Include geosynchronous satellites
defaults off and excludes observer distances of 30,000 km or more; this approximate
filter also excludes distant highly elliptical objects. Include unlit defaults
on and uses the existing snapshot illumination flag. Preferences persist and
combine to filter the sheet list and subtitle count; sky markers remain unchanged.
The filled filter icon indicates that at least one exclusion is active.

Reviewed the compact header in dark mode in `filters-sheet-dark.png`. The
menu toggle wiring was inspected in code; menu interaction was not automated
because the available simulator input tool is incompatible with Xcode 27.
Simulator and device builds succeeded; installed and launched on the connected
iPhone successfully.

## Search refinement

Removed the expanded sheet count subtitle and added an always-visible native search bar below the header. Search matches names, aliases, and NORAD numbers and combines with both filters. Reviewed `search-sheet-dark.png` in dark mode. Simulator and device builds passed; installed and launched on the connected iPhone. Search input automation remains unavailable due to the Xcode 27 input-tool incompatibility.

## Filter button relocation

Moved the inclusion menu out of the sheet to a separate 52-point circular interactive glass button to the right of the Passing now bar. Existing preferences and list filtering are preserved. Reviewed `filter-bar-dark.png` on the iPhone 17 Pro Max simulator in dark mode. Simulator and device builds passed; the updated app was installed and launched on the connected iPhone.

## Consistent sky filtering

Both inclusion preferences now filter the live satellites sent to the planetarium controller as well as the Passing now count and sheet. Preference changes refresh the controller immediately; excluded selections and their tracks clear immediately. The full propagated result set remains available for restoring inclusions. Added a regression covering immediate selection/track removal and re-selection after restoration. Reviewed `filtered-sky-dark.png` with the existing sunlit ISS fixture. Simulator and device builds succeeded; installed and launched on the connected iPhone.

## Single-line bar

The collapsed control now reads “Passing now: number” on one line with no satellite icon or subtitle. Its 52-point capsule aligns with the adjacent 52-point filter circle. Reviewed `single-line-bar-dark.png` in dark mode. Simulator and device builds passed; installed and launched on the connected iPhone.

## Distance filter panel

Replaced the menu with a compact popover containing a three-stop slider: LEO only (<6,000 km observer range), Up to MEO (<30,000 km), and All. Descriptions change with the slider and explain observer range versus altitude and approximate orbit categories. Include unlit has a leading moon and trailing checkbox. Existing geosynchronous preferences migrate to medium/all. Reviewed `filter-panel-dark.png` using a test popover anchor; simulator and device builds passed.

## GPS viewport reset

Found that `.id(observer)` recreated the SwiftUI planetarium and its StateObject controller whenever a fresh location replaced the cached coordinates. Removed coordinate-based identity; observer changes now refresh the controller projection/ephemerides in place, clearing obsolete live selections/results while preserving camera direction and field of view. A regression covers observer refresh and reconfiguration after panning/zooming, checks renderer identity, and verifies that the sky projection still changes. Reviewed `camera-refresh-dark.png` for appearance; the screenshot itself is not a GPS timing reproduction.

Updated distance limits to <600 km / <23,000 km / unlimited, and removed the second explanatory paragraph. Reviewed `filter-limits-dark.png` in dark mode. Both builds passed; installed successfully on the connected iPhone after a transient connection retry.

## Sky now tab states

Sky now uses a dedicated outline vector asset when inactive and the filled moon/stars symbol when selected. Reviewed `unselected-tab-dark.png` (test forecast content is deliberately empty) and the selected state in `selected-tab-dark.png`. Both simulator and device builds passed.
