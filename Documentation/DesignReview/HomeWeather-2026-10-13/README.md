# Home weather endpoint recovery — October 13, 2026

The installed app requests `GET /api/v1/forecast` with rounded coordinates and
`hours=2`. An authenticated request reproduced HTTP 404 with `NOT_FOUND` while
`/health` was healthy and WeatherKit configured. Anonymous Firebase authentication
using the registered iOS client succeeded. `/v2/forecast` rejects coordinate-only
queries with `INVALID_SITE`; it cannot replace the app endpoint without moving
weather to an observing site's location.

The ClearSkyChart site-based API rebuild removed the public v1 route while
preserving only the private pass-notification weather service. The repair lives
in the adjacent ClearSkyChart worktree on `codex/fix-satellite-weather`:
`/Users/sihaolu/.codex/worktrees/e311/ClearSkyChart`.

The repair restores the v1 iOS response contract with the existing Firebase
authentication and per-user quotas. It validates coordinates and `hours=2`
before charging quota or calling WeatherKit, and uses the shared WeatherKit H3
cache. It preserves source timestamps, attribution and stale flags; the iOS
15-minute freshness and current-hour checks remain valid. It calls only
WeatherKit. The v2 site restrictions and private notification service are
unchanged.

All 47 backend tests pass, including four compatibility regression tests for
contract/coordinates, authentication/validation, quotas, and degraded providers.
The existing site HTTP test now expects authentication on v1 instead of route
removal. The backend integration guide documents this installed-client contract.

No app code or analytics measurement changes are needed. Existing versions
recover through the same request once the API deployment completes. Users can
tap “Weather unavailable” or pull to refresh to bypass the existing 15-minute
outage backoff.

Production verification: deployed only `functions:backend:api` to
`clear-sky-chart`; Firebase reported a successful update. A new anonymous iOS
client session fetched HTTP 200 from the original app URL with schema version 1,
provider status `ok`, `stale=false`, source age under one second, two hours,
current temperature 21.84°C / `Clear`, daylight, and Apple attribution.
The disposable authentication session was deleted. Backend fix commit:
`3d766f7`. Live-response captures are local verification artifacts and are not
tracked in Git.

App verification: all six existing `HomeWeatherTests` passed on iPhone 17 Pro
Max / iOS 27.0. Debug simulator and device builds succeeded. The device identifier
was rediscovered, and the latest Debug app was installed and launched on
Sihao’s iPhone. Routine Debug and test telemetry guards remained in effect.

Dark-mode visual review confirmed the rebuilt app's live San Francisco header
with the sun icon, “71° Clear”, and loaded station passes. Screenshots are kept
locally outside Git.
The simulator was explicitly set to dark mode before capture. The app was
relaunched without the test-host snapshot environment after the test run.
