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
- Tapping the hero or a pass row pushes that specific pass onto the forecast stack;
  the notification and URL deep-link sheet is unchanged. The dedicated “Where to
  look” button and redundant captions from the draft are removed. All passes
  retains access to individual stations.

## Navigation

Every destination reachable from home is a `ForecastRoute` value appended to
`forecastPath`: `.allPasses` and `.pass(_:)`. The earlier build
mixed a `navigationDestination(isPresented:)` for All passes with value-based
links inside a path-bound `NavigationStack`. That combination let a pop of the
station or pass screen re-present All passes, so going back appeared to show the
same screen twice. With one path there is exactly one screen per pop, and the
home sky animation resumes when the path is empty. The station detail and its
nested pass list keep pushing their own values onto the same path.
- The hero card's Remind me button turns on ISS and Tiangong push reminders. It is
  the only place that requests notification permission; onboarding never prompts.
  After the OS grants access the device registration is written to Firestore
  (`users/{FCM token}`), which is what subscribes it to backend pass reminders.
  No local notification is scheduled. Once permission is granted the button is
  hidden. Inside the five-minute window before a pass the action becomes Start
  observing regardless of permission. A denied prompt shows the existing
  notifications-disabled alert and leaves the device unregistered.
- Push registration on launch and on location change is also gated on the OS
  authorization state, so a device that never allowed notifications is not
  written to `users`.

## Pass list

- Home “Coming up” and the All passes screen share `ObservationPassRow`: a glass
  station icon, the short station name with a peak-elevation capsule (filled at
  40° and above), rise → set compass directions with the visible minutes, and the
  start time. Home rows add the day under the time; All passes groups rows into
  day cards (Tonight, Tomorrow, then weekday and short date) so the day is not
  repeated per row.
- Rows sit in surface cards with a single inset hairline between them. The
  earlier `List` drew both its own separator and the row's overlay, which showed
  as a double line.
- The station video cards from the original overview (`SatelliteOverviewCell`,
  with the ISS and Tiangong clips) now head the Satellites tab above the
  categories, sharing the home `ForecastModel` so passes load once. All passes no
  longer has an Explore section; station detail is reached from the Satellites tab
  through its own navigation path.

## Station icons

`station_iss` and `station_tiangong` in `Images.xcassets` are low-poly glass
renders produced by [stations.py](stations.py) in Blender 4.5 (EEVEE, orthographic
elevated three-quarter camera, transparent film, 512 px then downscaled to 64/128/192).
The ISS is teal glass with the eight-wing truss, the S1/P1 heat radiators hanging
perpendicular to the arrays, and the pressurized modules below the truss centre, so
the silhouette reads as a solid object rather than a flat cross; Tiangong is warm
peach glass in its T configuration with paired wings on the lab ends. They are stylized silhouettes,
not engineering models. Re-render with:

```bash
/Applications/Blender.app/Contents/MacOS/Blender -b -P Documentation/DesignReview/ObservationHome/stations.py -- /tmp/render
```

## Sky illustration

The rise-to-set bearing uses the signed **minor arc** (at most 180°), including
wraparound at north. Culmination no longer chooses the hemisphere. Exactly opposite
directions are an unavoidable 180° tie and consistently use the positive arc.

The sky is rendered directly into the final view. `ChartRenderer` samples the
app's original spherical NASA galaxy texture for each output pixel's sky ray and
evaluates the in-app planetarium's night/twilight palette in that direction. There
is no intermediate circular sky image or distortion shader. The atmosphere keeps
the planetarium's directional terms but lifts the night sky to the sky chart's
illustration levels: a deep blue zenith, a hazier blue horizon band, a residual
scattering term while the Sun is within 18° of the horizon, a violet twilight rim
and a warm solar aureole. Previously the planetarium's radiometric night values were
used unchanged, which rendered a fully dark pass as near-black with no visible
atmosphere. `observation-sky-twilight-dark.png` in `../after` records the twilight
case; `observation-path-*.png` record a dark pass. A stereographic camera
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
versus remaining **preview** time. The dotted track is stroked over the whole pass
from fixed sample points and the solid elapsed portion is painted on top, so the
dash phase does not crawl as the cursor advances. Teal versus slate indicates illumination,
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
- [Low pass animation](low-pass-animation.mp4): the 10° ISS pass of September 29,
  2026 at 8:54 PM, reached by launching the Debug build with
  `-debugMockedOffsetDays 4.16` on September 25. The camera zooms toward the
  horizon for a low culmination, so the rendered sky covers a wide, shallow band.
- [Home screenshot](home-runtime-dark.jpg)
- [All passes](all-passes-dark.jpg) and [scrolled to the end](all-passes-explore-dark.jpg)
- [Satellites tab with station cards](satellites-stations-dark.jpg)

The Debug-only `-debugMockedOffsetDays <days>` launch argument seeds the debug
menu's mocked date offset, which is useful when the simulator has no shake gesture.

Both show the running app in dark mode with a simulated San Francisco observer.
