# Station pass Live Activities

The native implementation follows the reviewed Moonstone arc design. A person
taps the toolbar eye (**Follow live**) in a visible ISS or Tiangong pass detail.
The eye becomes filled once ActivityKit accepts the activity; tapping again stops it. One pass
can be followed at a time, within the next 24 hours. ActivityKit schedules it two
minutes before the first illuminated interval or starts immediately if that time
has passed. Disabled authorization, expired opportunities, another followed pass,
and ActivityKit failures have localized messages; a failed request is not success.

## Rendering and localization

The shared WidgetSupport views supply the Lock Screen and expanded Dynamic Island
arc, station artwork, peak altitude, localized directions, and countdown. Compact
and minimal presentations use station artwork. The arc uses 41 propagated samples
with exact illumination boundary splitting. All-lit, shadow-emergence, shadow-entry,
and multiple illumination intervals share one model. No fake moving position is
shown. There is no redundant “Sunlit pass” subtitle. Fully illuminated passes omit
the shadow legend. Taps deep-link to the selected pass and its original observer.

Strings reside in WidgetSupport's eight localized resource tables. Locale-aware
formatting is used for dates, elevation copy and accessibility labels; countdowns
use native date-based SwiftUI Text. The resource lookup explicitly resolves the
Swift package bundle. Locales: en, es, fr, pt-BR, ru, zh-Hans, ja, ko. Translations
have not received independent native-speaker review.

## Background lifecycle boundary

ActivityKit schedules presentation locally and keeps the date-based countdown running.
The app also requests a per-activity push token for immediate and scheduled starts.
Token and activity-state observers reconcile a durable registration/cancellation
outbox, including rotations, relaunch and movement cancellation. Foreground retries
are throttled to 30 seconds after failures; a short OS background task allows an
in-flight registration to finish. Registration is not guaranteed if the app is
terminated before obtaining a token or completing the upload.

The backend validates App Check (App Attest) and an activity-specific cancellation
secret, stores the minimal illumination schedule, and schedules Cloud Tasks at
rise, illumination transitions and set. The delivery handler is private and uses
OIDC-authenticated tasks. Firebase Admin's Live Activity sender includes the FCM
and ActivityKit tokens. It sends no routine alerts. Delayed jobs calculate the
current phase instead of replaying their original phase; end removes server tokens.
Cancellation tombstones prevent delayed registration from resurrecting a stopped
activity. TTL removes expired records. Cloud Tasks names are deterministic, so
registration retries don't multiply boundary tasks. Push delivery remains at-least-once;
ActivityKit timestamps order updates, and APNs timing is not guaranteed.

Wire schedule dates and APS timestamps are Unix seconds. `content-state.target`
uses seconds since 2001 to match Swift's default Codable Date decoder. Keep this
conversion covered by backend tests when changing ContentState.

The stale fallback remains necessary: expanded content shows the fixed set time
and “Open app to update”; compact content shows a clock. Simulator/test activity
requests do not register with the production backend. Debug time travel cannot
follow a pass. No extra location or notification permission is requested.

Deploy with `pass-prediction/scripts/deploy_live_activity.sh`. App Attest must be
registered for the Firebase iOS app and its Apple Team ID; use the production
App Attest entitlement even for device Debug builds, as required by Firebase.
App Check enforcement applies to this new registration endpoint, not existing
Firestore/reminder clients. Do not disable verification to troubleshoot a device.

Apple references:
- https://developer.apple.com/documentation/activitykit/displaying-live-data-with-live-activities
- https://developer.apple.com/documentation/activitykit/activitycontent/staledate

## Verification

See the associated locale evidence and test log. Native dark-mode renders cover
all eight locales, both stations, three illumination scenarios, six states, and
Lock Screen, expanded Island, and large-text widths. State tests cover illumination
boundaries, expiry, payload size, and compiled bundle lookups.

Verified September 27, 2026: [locale review and test evidence](../DesignReview/LiveActivity-2026-09-27/README.md).
Significant device movement (over 2 km from the activity observer) invalidates the
activity on location updates; changing the selected location stops it immediately.

## Remote pipeline verification (2026-09-27)

- Backend unit suite: 59 tests passed, including 10 Live Activity cases covering
  schedule validation, all illumination patterns, default Swift date encoding,
  cancellation tombstones, token revisions, delayed delivery, and OIDC audience.
- Simulator state/localization and ActivityKit lifecycle tests: 2 passed.
- Simulator and physical-device Debug builds succeed. The device build is installed
  on the connected iPhone; the separate simulator uses iPhone 17 Pro Max / iOS 27
  in dark mode to avoid interrupting another task's screenshot capture.
- App Check API enabled and App Attest configured for the existing Firebase iOS
  app and registered Apple Team ID. Registration and private delivery functions,
  a dedicated boundary queue, least-scope task invoker and expiry TTL deployed.
- Live endpoints reject missing App Check (401) and missing OIDC (403). The
  authenticated no-send queue smoke test returns 204 using the Cloud Run service
  URI as OIDC audience. The Functions alias is not a valid audience for that service.
- Real-device registration returned 204. With local phase updates disabled, the
  app was backgrounded; on resume the phone reported the remotely delivered
  shadow and visible transitions. A second background interval received shadow
  and ended states; the server retired both tokens. The app was relaunched normally.
  See [device evidence](../DesignReview/LiveActivityAPNs-2026-09-27/README.md) for
  receipt timestamps and the remaining distribution/offline/device checks.

For a repeatable developer-only check, launch a Debug device build with
`-liveActivityPushReview` when no activity is already running. It creates a short
synthetic shadow-emergence/shadow-entry pass, disables local phase updates, and
writes only received phase names/timestamps to Documents/live-activity-push-review.json.
The flag is absent from Release builds. Relaunch normally after the check.
