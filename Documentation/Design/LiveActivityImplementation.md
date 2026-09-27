# Station pass Live Activities

The native implementation follows the reviewed Moonstone arc design. A person
chooses **Follow pass live** in a visible ISS or Tiangong pass detail. One pass
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

This is a local ActivityKit implementation; it does not add or deploy an APNs
Live Activity service. The OS can start a scheduled activity while the app is
suspended and keeps date-based countdowns running. The foreground session updates
phases at their boundaries and ends expired activities. Each content update has a
stale date at the next boundary. When stale, expanded content shows the pass's fixed
set time and an “Open app to update” hint; the compact presentation shows a clock.
It does not keep claiming a station is visible. The OS controls stale refresh and
dismissal timing. Automatic background phase delivery and exact-time background
ending require a future APNs integration; a foreground timer is not such a service.

No background fetch, location permission, notification permission, or server token
registration is added by this feature. ActivityKit's scheduled alert is separate
from the app's existing reminders. Debug time travel cannot follow a pass.

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
