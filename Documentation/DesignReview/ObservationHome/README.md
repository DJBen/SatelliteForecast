# Observation home

Implemented on `codex/observation-home` in a separate worktree, based on the
committed app at `1834f8a`. In-progress widget and backend edits in the original
checkout were not copied or modified.

## Behavior

- Home merges visible ISS and Tiangong passes by the start of the sunlit interval,
  removes expired opportunities, and presents one actionable next observation.
- The location control opens the existing city picker. Device permission is
  requested only after the user chooses current location. Denied access keeps
  city selection available.
- Tapping the hero or a coming-up row opens that specific pass through the existing
  timed detail route. The dedicated “Where to look” button and redundant captions
  from the draft are removed. All passes retains access to individual stations.
- The reminder uses the first sunlit interval minus five minutes. It uses the
  existing notification service; success is shown only after OS acceptance.
  Inside the five-minute window the action becomes Start observing. An existing
  reminder can be cancelled from the card.

## Sky illustration

Uses the **app** `BackgroundSkyView`, `SkyChartAtmosphere`, Milky Way,
`SkyChartTheme` spectral point sources, observer-aware Moon, and planetary body
renderer. The home illustration now views the sky dome from 12° above the horizon,
with rise at the left and set at the right. Its vertical extent fits the pass;
this preview is an overview, not an angular scale. The full all-sky chart remains
available on tap. A dotted, curved horizon replaces the circular chart border.

A Metal layer effect reprojects the existing diffuse sky texture using the inverse
of the track projection. Stars, Moon and planet disks use the same projected
positions but preserve their original point-source glow and round artwork. The preview disables the chart's UIKit star-tap
overlay so it can be composited correctly. Star names, constellation lines, planet
names and planet symbols are hidden in this preview only. Stars are limited to
magnitude 2.5 or brighter (previously 4.5); full chart defaults are unchanged.

The background is prepared at culmination on the existing renderer actor. A
small Canvas interpolates precomputed orbital samples at 30 fps over a 12-second
preview plus a three-second end hold. Solid versus dotted indicates elapsed
versus remaining **preview** time. Teal versus slate indicates illumination,
independently of playback position. Two arrowheads show travel direction.
Foreground tracks have a dark under-stroke to remain readable over stars.

Animation pauses for Reduce Motion, inactive scenes, offscreen scroll content,
other tabs and presented destinations. Snapshots freeze playback deterministically.
No additional network asset source or widget renderer is used.

## Verification

- Build/run and dark-mode visual review: iPhone 17 Pro Max, iOS 27 simulator.
- 45 selected regression and snapshot tests passed (0 failures). Coverage: dome
  orientation across north, body visibility, forecast ordering, duplicates, visibility,
  shadow-window reminder time, expiry, stale results, location search and analytics.
  The final point-source rendering refinement also passed the native screenshot run.
- Native dark captures cover home, missing location, empty forecast, large text,
  and playback at 20% and 82% (under `../after/observation-*.png`).
- Interactive runtime: choosing simulated San Francisco location, permission
  request after the button tap, live forecast, direct pass detail and the denied
  notification path, detail dismissal, and All passes navigation/back. The rejected
  request leaves the home action unscheduled. Successful notification delivery
  was not tested interactively in this run.
- New home copy is localized in English and Simplified Chinese. Other app locales
  currently fall back to the English home strings; existing chart/picker/detail
  localizations are retained.

The example review fixture uses the recorded ISS elements from onboarding,
September 9–10, 2026, and observer 37.486743, -122.226560. Snapshot test dates are
formatted in UTC; runtime captures use the simulator's local time zone. They are
review evidence, not a store screenshot set or a public release.

## Runtime preview

- [Home animation](home-animation.mp4)
- [Home screenshot](home-runtime-dark.jpg)

Both show the running app in dark mode with a simulated San Francisco observer.
