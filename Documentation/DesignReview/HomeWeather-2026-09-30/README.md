# Home weather integration

The location row's trailing edge shows an SF Symbol for the WeatherKit condition,
a locale-formatted temperature, and condition text on one line. If the full
condition cannot fit, the row retains the icon and temperature; the full condition
remains available to VoiceOver and in weather details. Apple Weather branding at
the bottom of the forecast and in weather details links to the returned
data-source attribution. Tapping the weather opens details that
identify it as the current-hour forecast. Loading and retry states are independent
of satellite pass loading. Accessibility text sizes move weather to a trailing row
below the location.

API: `https://us-west1-clear-sky-chart.cloudfunctions.net/api/v1/forecast`.
Named Firebase app: `ClearSkyWeather`, project `clear-sky-chart`, iOS registration
`1:4137038259:ios:b34400916d7627caba5bc6`, bundle `io.djben.SatelliteForecast`.
Public client configuration is in HomeWeather.swift; no server secrets or Auth
tokens are bundled. FirebaseAuth persists and refreshes the anonymous session.
The existing default Firebase configuration is retained.

Requests use two hourly samples and coordinates rounded to 0.01 degrees to avoid
GPS jitter. Successful data is reused for up to 15 minutes and checked against
its forecast hour; failed automatic requests back off for 15 minutes. A cancelled
or superseded response cannot replace weather for a newer location. Manual pull
to refresh and tapping Weather unavailable request another attempt. Background
and offscreen polling stops. Coordinates outside the backend's supported bounds
(±89 latitude / ±179 longitude) do not initiate a request.

The ClearSkyChart backend now includes nullable `conditionCode` and `daylight`
fields in its existing hourly weather response. The additive update was deployed
without changing existing schema version, endpoint permissions, cache policies,
or rate limits. Its TypeScript build and all 25 tests passed. A deployed request
using the registered iOS app's API key and a disposable guest verified HTTP 200,
real WeatherKit data, both fields, and attribution. The guest was deleted;
`live-forecast.json` contains public forecast evidence and no credentials.

Validation: 7 targeted iOS tests passed (6 HomeWeatherTests plus the dark home
snapshot review) on iPhone 17 Pro Max / iOS 27. The app was rebuilt and relaunched
for live review. `live-home-dark.jpg` shows real authenticated San Francisco
weather at the location row’s trailing edge. `observation-home-weather-dark.png`
and `observation-home-weather-large-text-dark.png` use deterministic fixtures
for standard and accessibility text sizes. All were visually reviewed in dark
mode. The localization audit passed across eight locales.

The compact follow-up replaces the three-line header weather with one line:
icon, temperature, and condition. Narrow layouts fall back to icon and
temperature. Source credit moves to the forecast footer and weather details.
The app was rebuilt and rerun on iPhone 17 Pro Max in dark mode;
`compact/live-home-dark.jpg` was visually reviewed with live San Francisco
weather. This presentation-only follow-up adds no analytics events.

Cache verification: 2 focused iOS cache/coordinate tests and all 25 backend tests
passed. Three deployed requests (37.77, 37.7701, and 37.78 latitude at −122.42
longitude, two hours) returned the same WeatherKit H3 cell, source fetchedAt,
and weather samples. `cache-verification.json` records the checks without Auth
credentials. The disposable verification guest was deleted.

Boundary qualification: rounding suppresses GPS changes within the same 0.01°
app bucket. Even a small movement across a rounding boundary creates a new app
input and can request Firebase again. A fresh backend WeatherKit cache still
serves that request when the rounded coordinates fall in the same H3 cell and
the requested start hour/hour count match. Crossing an H3 cell boundary or
expiry can fetch upstream data. There is currently no radius/hysteresis rule
that guarantees reuse for every small movement near a boundary. App memory
cache is scoped to the current weather model, while the backend cache is shared
and persisted in Firestore.
