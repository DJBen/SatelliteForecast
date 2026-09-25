# Product analytics and screen performance

The app uses the existing Firebase Analytics installation. `Native/AppAnalytics.swift` owns the event vocabulary and SwiftUI screen modifier. Firebase automatic screen reporting is disabled in the app plist so hosting-controller names do not compete with our screen names.

## Collection and data boundaries

Release builds send events after Firebase has been configured. Debug builds send these custom events only when launched with `-FIRDebugEnabled`; snapshot tests, XCTest hosts, and previews never send them. This guard applies to our instrumentation, not Firebase's own automatic lifecycle events. No separate Firebase project, dashboard, or custom definition is provisioned by the code.

Parameters contain fixed labels and numeric counts/timings only. Do not add coordinates, place names, queries, satellite names, notification identifiers, tokens, raw errors, or user IDs. Firebase still supplies its standard app/device/session metadata. Existing Firestore registration is separate from this analytics instrumentation.

## Screens

`screen_view` includes Firebase's standard `screen_name` and `screen_class`, plus the custom `screen` parameter. Names are stable across locales.

| `screen` | Destination |
| --- | --- |
| `onboarding` | Welcome and prediction introduction |
| `forecast` | Main station forecast cards |
| `categories` | Satellite categories |
| `satellites` | Searchable satellite list |
| `passes` | Calculated passes for one satellite |
| `pass_detail` | Individual pass chart and compass |
| `sky_detail` | Expanded sky chart sheet |
| `sky_now` | Experimental realtime sky |
| `settings` | Settings overview |
| `location` | Location search and selection |
| `alarms` | Scheduled alarm list |
| `alarm_setup` | Individual alarm configuration sheet |
| `ephemerides` | Orbital-data management |

The pass controls are labeled “Chart” and “Planetarium”; the adaptive compact/accessibility layout does not change destination screen names or event semantics.

The modifier sits on destination content, not the surrounding navigation stack. It records when that content appears while active and when it returns from background, deduplicating repeated appearance callbacks until disappearance. Visits are not unique users. Sheet presentations can leave their underlying screen mounted: a sheet dismissal does not necessarily emit another underlying `screen_view`. Custom events always carry an explicit `screen`, so asynchronous work does not inherit whichever screen Firebase last saw. Do not use these visits to calculate exact dwell time. Debug menus and embedded previews are not separate product screens.

## Events

Every event includes `screen`.

| Event | Additional parameters | When / interpretation |
| --- | --- | --- |
| `screen_view` | `screen_name`, `screen_class` | Destination exposure; see lifecycle details above |
| `onboarding_step` | `step` (1 or 2) | Initial page and each selected-page change |
| `onboarding_completed` | — | User finishes onboarding, including replays |
| `location_selected` | `method` (`device`, `custom`) | A usable location selection is accepted by LocationService; resolving a search result alone is not a conversion |
| `flow_blocked` | `reason` | Forecast cannot start without location (`missing_location`), or current-location selection opens Settings because no fix is available (`current_location_unavailable`) |
| `refresh_requested` | — | User pulls to refresh forecast |
| `retry_tapped` | — | User retries loading the satellite catalog |
| `operation_started` | `operation` | A measured unit of work starts |
| `operation_finished` | `operation`, `outcome`, `duration_ms`; optional `result_count`, `reason` | One terminal outcome per started operation during normal task completion/cancellation |
| `alarm_scheduled` | — | OS notification center accepts an alarm and local state is persisted; screen is `passes` for a quick alarm or `alarm_setup` for the configuration sheet |
| `alarm_cancelled` | — | Explicit cancellation removes an existing scheduled alarm; `screen=alarms` denotes the alarm-management domain, not necessarily the visible screen |
| `notification_opened` | — | AppSession accepts a notification deep link; this does not guarantee the destination loaded. External URL opens are excluded |

Onboarding replay counts and rescheduling the same alarm count as actions, not new installations or unique reminders. Filter to first events per user/session when answering activation questions. `flow_blocked` may repeat on new forecast inputs; use affected sessions rather than raw event count as the friction denominator.

## Measured operations

| `operation` | `screen` | Timed boundary | Optional result count |
| --- | --- | --- | --- |
| `forecast_iss`, `forecast_tiangong` | `forecast` | Individual station pass request to accepted result | Calculated passes |
| `load_station` | `passes` | Station orbital-data request to accepted result | Satellites returned |
| `calculate_passes` | `passes` | Pass calculation request to accepted trails | Pass snapshots |
| `load_catalog` | `satellites` | Catalog request to accepted result, including explicit retry | Satellites returned |
| `load_sky_catalog` | `sky_now` | Active satellite request to accepted result | Satellites before LEO filtering |
| `location_search` | `location` | Suggestions request after debounce to accepted results | Suggestions |
| `location_resolve` | `location` | Selected suggestion resolution to pending location | — |
| `schedule_alarm` | `passes` or `alarm_setup` | Authorization request, preview generation, and OS scheduling | — |

Terminal `outcome` values:

- `success`: accepted nonempty result, resolved location, or scheduled alarm.
- `empty`: accepted request with zero results; not a service error.
- `failure`: genuine error, with fixed `reason` (`load_failed`, `calculation_failed`, `search_failed`, `resolve_failed`, `scheduling_failed`).
- `blocked`: scheduling could not proceed (`notification_permission_denied`, `alert_time_passed`).
- `cancelled`: navigation, superseded input, task cancellation, or stale response; excluded from technical error rates.

`duration_ms` uses monotonic uptime. A deferred cancellation finish is ignored after another terminal outcome, preventing double counting. Process termination may leave starts without finishes; those are not automatically failures. Forecast station operations run concurrently; do not add their durations together as screen latency. The result counts include all calculated passes, not just visible/prominent opportunities.

These metrics measure operation latency, including caches, networking and computation. Alarm latency also includes time spent answering the permission prompt. They do **not** measure frame rate, GPU cost, slow/frozen frames, time to first frame, or continuous sky propagation. No Firebase Performance SDK was added. Use Instruments for rendering diagnosis; compare these Analytics timings only within the same operation and outcome.

## Firebase / GA4 setup

1. Verify Analytics is enabled for the Firebase project used by the bundled `GoogleService-Info.plist`.
2. In GA4 Admin → Custom definitions, register event-scoped dimensions: `screen`, `operation`, `outcome`, `reason`, `method`, `step`. Firebase screen names/classes also have built-in reporting dimensions.
3. Register event-scoped custom metrics: `duration_ms` (milliseconds) and `result_count` (standard numeric unit). Definitions are not retroactive in standard reports.
4. Mark `alarm_scheduled` as the primary key event. Optionally mark `onboarding_completed` and `location_selected` as secondary key events. A screen visit or an alarm button tap is not a successful alarm conversion.
5. Use Funnel Exploration and, for percentile timing analysis, enable BigQuery export. Configure these in the console; the app does not modify console settings.

Suggested analyses:

| Question | Funnel / calculation |
| --- | --- |
| Where does onboarding lose people? | `onboarding_step=1` → `step=2` → `onboarding_completed`; analyze first-time cohorts separately from replay |
| Do forecasts lead to action? | `screen_view(forecast)` → `screen_view(passes)` → `screen_view(pass_detail)` → `alarm_scheduled`; allow indirect steps |
| Does browsing convert? | `screen_view(categories)` → `screen_view(satellites)` → `screen_view(passes)` → `alarm_scheduled` |
| Does the alarm sheet convert? | `screen_view(alarm_setup)` → `operation_started(schedule_alarm, screen=alarm_setup)` → `alarm_scheduled(screen=alarm_setup)` |
| Is location a blocker? | Sessions with `flow_blocked` → `screen_view(location)` → `location_selected`; break down `location_search` / `location_resolve` terminal outcomes |
| Which loads fail or return nothing? | Per screen + operation, failure or empty outcomes divided by success + empty + failure finishes; report blocked/cancelled separately |
| Which screens feel slow? | Median and p95 `duration_ms` by operation, successful outcome, app version, OS and device; show sample counts |
| Do reminders bring users back? | `notification_opened` → `screen_view(pass_detail)` for timed links; legacy links may visit `screen_view(passes)` first |

Use ordered, session-scoped funnels (or an explicitly chosen conversion window), counting users/sessions rather than dividing unrelated event totals. A missing downstream event indicates observed drop-off, not proof of a usability defect. Forecasts, pass calculations and location search can legitimately be empty.

## Validation and maintenance

- Launch a Debug build with `-FIRDebugEnabled` and use Firebase Analytics DebugView. Routine Debug launches intentionally skip custom telemetry. Use `-FIRDebugDisabled` to clear Firebase debug mode afterward.
- Exercise onboarding, tab changes, catalog selection, a pass, alarm setup, location search, and back navigation. Confirm stable names and one screen event per appearance; no extra hosting-controller screen names.
- Test denied notification access and an expired reminder time. Expect a blocked finish and no `alarm_scheduled`. A successful OS add must produce exactly one success finish and one conversion event.
- Cancel an in-flight request by changing location/query or leaving the screen. It must not become a technical failure or publish stale success. Search timings must exclude the debounce period.
- Tests in `AnalyticsTests` verify a single terminal outcome, numeric duration/count payloads, and distinct blocked/cancelled/empty/failure outcomes. Existing forecast/location/native tests exercise stale-response and cancellation behavior with telemetry disabled.
- After code changes, rebuild and run in the simulator; visual inspection stays in dark mode per AGENTS.md. Simulator timings are development evidence, not representative device performance.
- Update this file whenever adding a screen, operation, conversion, or parameter. Keep labels low-cardinality and document numerator/denominator and what a timer actually covers.

References: [Firebase screen views](https://firebase.google.com/docs/analytics/screenviews), [logging events and custom definitions](https://firebase.google.com/docs/analytics/ios/events), [DebugView](https://firebase.google.com/docs/analytics/debugview).

## Implementation verification (2026-09-17)

- `SatelliteForecastApp` built and ran on iPhone 17 Pro Max / iOS 26.5 simulator; forecast screenshot reviewed in dark mode.
- 47 targeted tests passed: AnalyticsTests, ForecastTests, LocationSearchTests, and NativeArchitectureTests.
- Runtime Firebase logs confirmed Analytics 12.4.0 startup and collection enabled. Receipt in the remote Firebase DebugView and GA4 console definitions/key events were not verified or configured from this workspace.
- Firebase debug mode was disabled again after the runtime check; the app was relaunched for review.

## Timed notification deep links

Notifications with `passTime` open the matching `pass_detail` screen directly;
older payloads open `passes`. Do not require a `passes` screen event when measuring
notification-to-detail conversion. URL links use the same destination screens but
do not emit `notification_opened`. Link parsing and pass matching add no telemetry
parameters; coordinates, times, URLs, and identifiers remain excluded.

Planetarium moon ephemerides load on demand below the close-zoom threshold and
cache valid windows locally. This adds no analytics operation/event or screen;
network timing is not counted as forecast or sky-catalog loading. Horizons
requests contain body IDs and time ranges, never the observer's coordinates.

The planetarium Follow Device toolbar control and automatic motion disengagement
on drag add no screen or analytics event. Motion samples and gestures are not
logged; existing measurement boundaries remain unchanged.

The profile-guided planetarium refactor isolates time controls, selection, and
navigation updates in child views. It does not add screens/events or change
analytics measurement boundaries. Release phone performance checks use the
existing Release telemetry rules; frame rates and motion samples are not logged.

The 1.8.0 localized time-selector width adjustment changes no events, screen names, or measurement boundaries.

Sky-label typography and cached bright-star names introduce no analytics events or screen changes. Name metadata is loaded through the existing star catalog, including asynchronous viewport-label lookups when zoomed; viewport positions and label choices are not logged.

Preview selection tracking and render-clock playback introduce no analytics events. Frame updates, tracking anchors, selected coordinates, and cached ephemeris interpolation are not logged; screen and conversion semantics remain unchanged.

Continuous planetarium live-time sampling, observed planetary inclinations, and
Sky Chart background filtering add no analytics events or screens. The clock
label's 1 Hz refresh and orbital sampling's 30 Hz refresh are rendering details;
existing operation and conversion measurement boundaries remain unchanged.

Sun-label spacing/color, physical planetary illumination, and Saturn ring
geometry change no screens, events, or measurement boundaries. The geometry
uses bundled ephemerides locally; reference Horizons queries are offline test
fixtures and add no production network or telemetry flow.

Century-range planetarium validation and IAU precession introduce no screen or
analytics events. Reference ephemerides are offline test data; application
calculations remain local and preserve all existing measurement boundaries.

The optional planetarium FPS readout uses local Metal presentation timestamps. It sends no telemetry and changes no screen names, events, or measurement boundaries.

Planetarium deep-star loading queries local indexed H3 cells on a dedicated actor. Region keys, camera directions, star IDs, cache statistics, and FPS remain local rendering state; no new analytics operations or per-region events are emitted. The existing `load_sky_catalog` operation still measures satellite catalog loading, not these star queries.


## Home Screen widgets

Widget timelines and configuration introduce no analytics events or new screen
names. Successful real-time station forecasts publish visible-pass summaries to
an App Group container; this storage is local and is not telemetry. Debug time
travel, tests, and previews do not publish forecasts. Widget opening enters the
existing app flow without emitting `notification_opened`. Location changes clear
the shared cache; existing forecast operation boundaries remain unchanged.

Large-widget sky-track sampling runs locally after the existing station forecast
results are accepted. It adds no screen, event, or telemetry parameter and is
excluded from the existing forecast operation timers. Azimuth/elevation samples
and illumination states stay in the local App Group cache.

Widget bright-star and solar-background preparation uses the existing local
catalog and pass observer/time. It adds no analytics events or parameters and
remains outside forecast operation timers. Star positions and spectral metadata
are cached locally only.
