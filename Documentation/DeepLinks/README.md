# Satellite and pass deep links

The app accepts notification taps and the `satelliteforecast` URL scheme. Both
routes retain the observer and optional pass time while the sky catalog loads.
They open in a dismissible navigation sheet after onboarding completes.

## URLs

- ISS pass list: `satelliteforecast://satellite/iss?lat=37.49&lon=-122.23`
- Tiangong pass list: `satelliteforecast://satellite/tiangong?lat=37.49&lon=-122.23`
- Specific ISS pass: `satelliteforecast://satellite/iss?lat=37.49&lon=-122.23&time=2026-09-18T07:00:00Z`

The time above illustrates the format; it is not a promised pass at that location.
Station aliases `25544`, `48274`, and `tianhe` are also accepted. Latitude and
longitude are required, in degrees. Optional `alt` is the observer altitude in
meters (defaults to zero). `time` is an ISO 8601 instant with a time zone. URL-encode
plus signs in time-zone offsets as `%2B`. Malformed coordinates, times, duplicate
parameters, and unknown station paths are ignored.

## Notification payload

APNs category remains `PASS`. Existing string fields `noradIndex`,
`satelliteCategory`, `lat`, `lon`, and `alt` retain their meanings. Optional
`passTime` is a string containing Unix seconds for the pass's culmination.
Local alarms use the same time field alongside their encoded observer. Existing
notifications without `passTime` continue to open the satellite's pass list.

Both Firebase handlers (`notify` and `notify_prominent`) attach this time when
available. This backend update must be deployed separately to affect live pushes.
Older installed app versions ignore the new field and continue opening the list.

## Resolving a timed link

The app recalculates a 90-minute window centered on the requested time using
current orbital data and the supplied observer. It opens the matching pass detail,
allowing up to five minutes beyond its rise/set for prediction drift. It never
silently substitutes another orbit. If no match exists, the sheet offers Retry
and View all passes. Historical predictions can differ from the original alert
because the app uses current orbital data.

External URL opens do not emit `notification_opened`. Notification taps retain
that event; a timed destination emits the existing `pass_detail` screen event.
No URL, timestamp, coordinate, or notification identifier is logged to analytics.

## Tests

- `DeepLinkTests`: station aliases, old/new payloads, local observer decoding,
  validation, buffered cold-start events, and pass matching bounds.
- Existing catalog integration test: legacy notification buffering.
- `python3 -m unittest discover -s pass-prediction/tests -v`: Python copy and
  timestamp serialization regressions; no notifications are sent.

## Simulator verification — 2026-09-17

Built and ran `SatelliteForecastApp` on iPhone 17 Pro Max / iOS 26.5 in dark mode.
Observer for these synthetic test links: 37.49°, −122.23°, altitude 0. Display
zone: America/Los_Angeles. No production device push was sent and nothing was
deployed. A temporary simulator alarm used to grant notification permission was
cancelled; zero scheduled simulator alarms remained afterward.

| Route | Observed result |
| --- | --- |
| ISS URL, no time | International space station pass list |
| Tiangong URL, no time | Tiangong space station pass list |
| ISS URL, `2026-09-20T03:53:00Z` | Sep 19 pass detail, culmination about 20:51:35 PDT |
| Tiangong URL, `2026-09-18T18:06:00Z` | Sep 18 pass detail, culmination 11:06:15 PDT |
| ISS legacy simulated APNs tap | ISS pass list |
| Tiangong legacy simulated APNs tap | Tiangong pass list |
| ISS timed simulated APNs tap, app running | Requested Sep 19 ISS pass detail |
| Tiangong timed simulated APNs tap, app stopped | Cold launch to requested Sep 18 Tiangong pass detail |
| ISS URL, `2026-09-20T04:25:00Z` (between passes) | No-match message; View all passes successfully opens ISS list |
| A second link while a destination sheet is open | Replaces the existing destination with the new station/pass |

The Tiangong example is a daytime pass: the chart correctly shows daylight while
the app remains in dark mode. Timestamp routing is independent of visibility.
Small differences of a few seconds occur when the numerical search is centered
on slightly different times; the resolver selects the same physical pass.

Reviewed screenshots:
[ISS list](iss-list-dark.png), [ISS detail](iss-detail-dark.png),
[Tiangong list](tiangong-list-dark.png), [Tiangong detail](tiangong-detail-dark.png),
[unavailable pass](unavailable-pass-dark.png).

The four `.apns` files here contain synthetic simulator payloads with no device
tokens. Replay one using `xcrun simctl push <simulator-id> io.djben.SatelliteForecast
<file.apns>`, then tap it in Notification Center. These fixtures exercise the native
notification delegate; they do not verify live Firebase-to-APNs delivery.

Automated results: 7 `DeepLinkTests` passed, the existing legacy notification
buffering regression passed, and all 10 Python notification tests passed.
