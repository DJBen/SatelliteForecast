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

The rise-to-set bearing uses the signed **minor arc** (at most 180°), including
wraparound at north. Culmination no longer chooses the hemisphere. Exactly opposite
directions are an unavoidable 180° tie and consistently use the positive arc.

The sky is rendered directly into the final view. `ChartRenderer` samples the
app's original spherical NASA galaxy texture for each output pixel's sky ray and
evaluates the in-app planetarium's night/twilight palette in that direction. There
is no intermediate circular sky image or distortion shader. A stereographic camera
uses one uniform scale for both axes, preserving local shapes rather than fitting
the background into a vertically stretched dome. The curved dotted horizon remains.

Stars are drawn from the catalog with `SkyChartTheme`'s point-source glow and
spectral color at magnitude 2.5 or brighter. Moon and planet disks reuse the app's
existing artwork and observer-aware positions. All celestial objects use the same
camera, remain unlabeled and retain their round shapes. The full sky chart remains
available on tap, with its defaults unchanged.

The background is prepared at culmination on the existing renderer actor at up
to two pixels per point. Rendering cancels when the pass, observer or size changes. A
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
- 47 selected regression and snapshot tests passed (0 failures). Coverage: minor-arc
  selection, north wraparound, direct ray/catalog alignment, uniform local scale,
  body visibility, forecast ordering, duplicates, visibility,
  shadow-window reminder time, expiry, stale results, location search and analytics.
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
