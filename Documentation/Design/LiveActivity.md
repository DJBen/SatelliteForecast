# Station pass Live Activity — mockup

Initial design exploration, 2026-09-27. The interactive mockup uses illustrative
pass times, directions, and elevation; it is not a propagated forecast or a native
simulator screenshot. The subsequent native implementation and lifecycle limits are documented in
[LiveActivityImplementation.md](LiveActivityImplementation.md).

## Design direction

Selected direction: a shared altitude arc in the Lock Screen Live Activity and
expanded Dynamic Island. Both use MoonstonePalette: charcoal page (#111214),
card (#1C1E22), soft white text (#ECEEF2), muted text (#A3A8B2), silver-blue accent
(#A9B9CE), and separators (#33363D). Cards receive an 8% accent tint near the lower
edge; pages stay neutral. The Dynamic Island retains system black.

The arc encodes altitude above the horizon. Peak elevation is labeled in degrees;
rise and set include compass directions and 0° horizon labels. Sunlit segments
are solid silver-blue; shadow segments are muted and dashed, with a small hollow
marker at the shadow crossing. A compact legend makes the distinction explicit.
The example curves and shadow boundaries are illustrative; native rendering must
use propagated altitude and illumination samples, including all shadow crossings.

Use the existing station_iss and station_tiangong artwork in the header, around
38 points on the Lock Screen and 34 points in expanded Dynamic Island. Keep the
station name beside it, with no icon obscuring the arc or implying a live position.
The compact Island previews 30-point station artwork and a countdown; evaluate
legibility natively and fall back to a simple glyph if the host space is too small.
At accessibility sizes prioritize readable content, allowing artwork to disappear.

Omit the redundant “Sunlit pass” subtitle during the visible segment; retain
starting-direction and shadow-state labels. Before the pass, count down to the visible interval. During the sunlit segment,
count down to shadow entry (or set if the pass remains sunlit). On entering shadow,
explicitly say “In Earth’s shadow” and label any remaining countdown “until set”,
never “viewing time left”. Finish at set. Reuse ObservationOpportunity visibility
boundaries, accounting for both altitude and illumination, rather than treating
all sunlit below-horizon or daylight geometry as an observable opportunity.

The updated mockup switches station artwork, peak elevation, direction, and
illustrative shadow geometry together. It previews before, sunlit, and shadow
states. No per-second position indicator is promised. Tap opens the matching pass
in the app. Native lifecycle and rendering now live in the shared WidgetSupport module;
see the implementation document for verification and background limitations.

## Implementation exploration

- The existing SatelliteForecastWidgetLiveActivity.swift contains the Xcode
  template. The widget bundle currently registers only the Home Screen widget.
- The app and widget target iOS 26. Shared ActivityAttributes and SwiftUI content
  can live in SatelliteWidgetSupport, already consumed by both targets.
- ForecastModel already loads both stations, excludes debug time travel and tests
  from widget publication, and invalidates shared forecasts when location changes.
- Offer an explicit “Follow pass” action for a selected visible station pass.
  Schedule the activity shortly before its visible interval. Avoid implicitly
  enrolling every user or scheduling all upcoming passes on every refresh.
- Verify scheduled ActivityKit start availability in the installed SDK and handle
  disabled Live Activities, scheduling capacity, cancellation, expired passes,
  location changes, and duplicate requests. Store enough observer/pass context
  locally for correct deep links; never log it.
- Use system date-based Text/ProgressView for countdowns while suspended.
  Scheduled start does not itself provide arbitrary timed content transitions or
  automatic end. Before implementation, choose and validate a reliable lifecycle:
  native scheduled-start behavior plus ActivityKit updates/end, with APNs where
  unattended phase changes or completion require them. A foreground Timer is
  insufficient. Stale UI must never keep claiming a pass is currently visible.
- If adding analytics, document fixed-label start/schedule outcomes in the metric
  catalog and keep preview/simulator runs out of custom production telemetry.
- Native implementation must be rebuilt, run, and visually inspected in dark mode
  on iPhone 17 Pro Max; this HTML exploration does not satisfy that verification.

Apple references:
- https://developer.apple.com/documentation/activitykit/displaying-live-data-with-live-activities
- https://developer.apple.com/documentation/activitykit/activity/request(attributes:content:pushtype:style:alertconfiguration:start:)
- https://developer.apple.com/documentation/activitykit/starting-and-updating-live-activities-with-activitykit-push-notifications

## Design system synchronization

Fetched origin/main and ran rebase on 2026-09-27. Git reported the branch already
up to date: origin/main (af4f25a) is an ancestor of HEAD (ebe6aa5). Moonstone was
present as staged local work on codex/moonstone-palette, not an incoming remote
commit. The staged work was restored with its index intact. The mockup now uses
the shared palette and reviewed Moonstone appearance instead of the old teal/navy.

## Illumination cases

The mockup now includes three selectable geometries in both expanded surfaces:

- Fully illuminated: solid arc throughout, no shadow marker or shadow legend.
  Countdown targets set while viewing, then shows completion.
- Appears from shadow: dashed rising segment becomes solid at shadow exit.
  Before emergence, show “In Earth’s shadow” and “until visible”; after emergence,
  remove the status subtitle and count down to set.
- Fades into shadow: solid rising segment becomes dashed on descent. Countdown
  targets shadow entry while viewing, then clearly switches to “until set”.

Each supports before/during/after viewing. These are illustrative nighttime passes.
Native visibility must also consider observer twilight, altitude thresholds, and
any additional shadow crossings; illumination alone does not guarantee visibility.
