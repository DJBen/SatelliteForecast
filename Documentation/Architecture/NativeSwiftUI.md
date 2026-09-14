# Native SwiftUI migration

The target architecture uses SwiftUI views, feature-owned Observation models, plain Swift domain logic, and explicitly injected services. No replacement architecture framework is being introduced.

## Historical first migration slice: Settings and the root view

- `AppSettings` is a main-actor Observation model owned by the loaded application view. Settings, root tab visibility, and the night overlay read the same instance. The two options remain session-scoped, preserving existing behavior.
- `SettingsOverviewViewImpl` owns its navigation path with SwiftUI State. It receives settings and ordinary closures that construct its child views. Its action enum, projected view state, reducer, and reducer wiring are removed.
- `RootView` receives a native tab Binding, settings, and view-building closures. It does not import SwiftRex, CombineRex, or CombineRextensions.
- `LegacyRootView` temporarily translates the existing tab store into that Binding. Keeping the existing tab action preserves the Sky Now loading effect and navigation consumers in features that have not yet migrated.
- Settings composition still constructs legacy location and alarm destinations. Those dependencies are confined to the wiring target; their services and view implementations have not yet migrated.
- Location selection changes domain state; the presented location view dismisses itself through SwiftUI. The reducer no longer pops a global Settings path, including when an action arrives with no location screen presented.

## Completion status (2026-09-14)

SwiftRex, CombineRex, CombineRextensions, the global `Store`/`AppState`/`AppAction`, reducers, middleware, projections, and the wiring package have been removed. No substitute Redux framework or generic event-dispatch runtime was added. The earlier sections below record the migration history rather than remaining dependencies.

- `AppSession` composes services and coordinates application lifecycle. Its observable navigation, location, notification, settings, and debug objects have explicit responsibilities; it does not contain a global screen state tree.
- Each remaining screen uses a concrete main-actor Observation model. Presentation belongs to SwiftUI bindings and dismiss actions. Small feature command enums describe local interactions; they are not broadcast to other screens.
- `OrbitalService` serializes cache access, parsing, and CPU predictions off the main actor. Downloads are validated before atomic replacement, valid stale files survive network failures, and cancellation is cooperative. Detailed screens load independently. Predictions are owned by the requesting feature and superseded work cannot publish late results.
- `ChartRenderer` isolates Core Graphics work. Chart models keep only the current rendered image, replacing earlier results instead of accumulating a global cache for every visited pass. The elevation chart receives the selected pass directly and calculates only the coarse snapshots it needs.
- Sky Now retains adaptive satellite refresh intervals, cancels when inactive, and invalidates results on observer or time discontinuities.
- `LocationService` owns Core Location and cancels superseded geocoding. `NotificationService` owns authorization, attachment generation, scheduling, cancellation, reconciliation, and persistence. App delegate callbacks buffer launch/deep-link events until composition is ready.
- `ScreenFactory` and `ViewFactory` are typed view-building closures only, with no subscriptions, state routing, reducers, or middleware.

The existing Swift language compatibility settings remain; this completes the architecture dependency removal, not a separate all-target Swift 6 language-mode migration.

## Working conventions

Keep ephemeral presentation state in views. Use a feature model when coordination warrants one. Pass dependencies through initializers; use protocols or closures at I/O and testing boundaries rather than layering abstractions over every function. Preserve pure reducers only for complex state transitions. Async does not imply background execution: expensive work must have an explicit execution boundary, immutable inputs, cancellation, and protection against stale results.

## Validation

Run `python3 scripts/test-screens.py` to build the app and run the hosted integration and screenshot tests. Baseline comparison is the default; do not record new baselines for this architecture-only change. `NativeArchitectureTests` covers root tab visibility with a native hosted SwiftUI view, shared Observation notifications, property-specific invalidation, location selection without a Settings navigation stack, and rejecting an unavailable current location.

### First-slice verification (2026-09-13)

The app builds on iPhone 17 Pro / iOS 26.5. All 10 non-screenshot tests pass, including the 5 new native architecture tests. Of 40 light/dark screen comparisons, 38 pass without baseline changes.

The two Mission Control comparisons fail because their live MapKit rendering differs from the recorded images (including a marker absent from the baseline). A control run against untouched `main` at `858a6f7`, selecting only the Mission Control screenshots, reproduces both failures at approximately 1.1% mean pixel difference against a 0.4% threshold. This is a pre-existing snapshot limitation; the threshold and baselines have not been relaxed or replaced. The full suite consequently reports 10 passed / 1 failed test method. Stabilizing MapKit screenshot inputs remains separate work.


## Second slice: location search and alarm settings

`LocationSettingsView`, `ObserverCell`, `AlarmSettingsView`, and `AlarmSettingsCell` now receive ordinary values and callbacks. They do not import SwiftRex, CombineRex, or CombineRextensions. The alarm list keeps deterministic display order and deletes by notification identifier. The redundant screen actions and their forwarding middleware are removed.

`LocationSearchModel` owns query results, lookup progress, errors, and pending confirmation on the main actor. Query tasks are tied to SwiftUI's task lifecycle. Resolution is cancelled when superseded or the screen closes. Generation checks reject late results even if an injected service ignores cancellation. `LocationSearchClient` injects suggestions, address resolution, and debounce behavior for tests. Its live MapKit adapter creates an independent completer per query, resumes each continuation at most once, and forwards cancellation to MapKit.

`LegacySettingsView` is the temporary subscription/dispatch boundary for shared observer location and scheduled notifications. Query text, autocomplete results, and screen navigation no longer enter the global store. Location persistence, prediction updates, and notification cancellation continue through the existing services, preserving behavior during the incremental migration.

### Verification

- The simulator build succeeds. All 16 behavior/integration tests pass, including six new search and alarm tests.
- 36 of 40 screenshot comparisons pass without recording or changing thresholds. The four remaining failures are the live MapKit globes in Pass Forecast and Mission Control, in light and dark mode. Inspection of actual captures shows missing/different basemap imagery; this is the same external map-rendering limitation documented above, now also visible in the embedded globe. The suite reports 16 passed / 1 failed test method.
- On iPhone 17 Pro / iOS 26.5, exercised onboarding, location and notification permission prompts, Settings navigation, live San Francisco address suggestions, cancellation of confirmation, confirmation and return to Settings, the selected location's map, and opening/entering edit mode in the empty alarm list. Deletion with populated data is covered by the identifier/order regression test rather than scheduling real alarms during this manual check.

Simulator captures: [search](SimulatorChecks/location-search.jpg), [confirmation](SimulatorChecks/location-confirmation.jpg), [selected location](SimulatorChecks/location-selected.jpg), [alarm edit mode](SimulatorChecks/alarms-edit.jpg).

Remaining roadmap items are Forecast, Sky/cache isolation, shared service/lifecycle coordination, and final removal of the legacy store/packages. This slice does not claim those are complete.


## Third slice: Forecast overview

`ForecastModel` is a main-actor Observation model with injected loading, clock, and sleep dependencies. SwiftUI owns its task lifetime. ISS and Tiangong publish independently, with cancellation and generation checks rejecting superseded results. Countdown ticks reuse pass results; expensive predictions refresh hourly, on observer/debug-time changes, or on pull to refresh.

`ForecastService` is an actor that owns orbital-data reads, validation, cache writes, and CPU prediction work. It shares the existing six-hour TLE cache filenames with legacy screens, validates downloads before atomic replacement, and falls back to valid stale data on network failure. Cancellation never triggers that fallback. Prediction loops now check cancellation, and malformed TLE lines/numeric fields throw instead of force-unwrapping downloaded input.

`LegacyForecastView` only bridges shared location, debug offset, and navigation. The old overview loading middleware and location-triggered overview recalculation are removed. Detailed pass screens still use the legacy services; their wrapping view now explicitly starts its own load when opened, rather than relying on the overview to populate global state. Notification/deep-link routing remains in place.

### Verification

Twelve new tests cover overlapping location requests, independent satellite failures and recovery, missing location, cancellation, injected time and debug offsets, countdown expiration, hourly refresh, fresh-cache reuse, prediction parity, stale-cache preservation, malformed input, and prediction-loop cancellation. Screenshot fixtures use an injected native Forecast model without starting live loads.

- Final iPhone 17 Pro / iOS 26.5 run: build succeeded, all 28 behavior/integration tests passed. The screenshot test method failed: 34 of 40 comparisons passed. Pass Forecast and Mission Control differ in live MapKit imagery; Ephemerides differs in relative modification-time labels (light/dark for each). Baselines and thresholds remain unchanged.
- Simulator verification: loaded ISS and Tiangong forecasts at San Francisco; changed simulated location to New York and verified different pass elevations/countdowns; opened the ISS pass list, then an individual pass with its chart and star map, and navigated back. A transient SQLite “vnode unlinked while in use” error after the test run cleared on a full app restart; the successful captures below were taken afterward.
- Captures: [San Francisco overview](SimulatorChecks/forecast-san-francisco.jpg), [New York overview](SimulatorChecks/forecast-new-york.jpg), [ISS pass list](SimulatorChecks/forecast-details.jpg), [individual pass](SimulatorChecks/forecast-pass.jpg).

This was the remaining work at the end of the third slice; it is now completed as described above.

## Final migration verification

Behavior tests now exercise the native services and feature models directly. Screenshot fixtures no longer construct a Redux store or invoke middleware. Their ephemeris browser uses an isolated empty directory matching the original fixture, so simulator downloads and relative timestamps cannot alter the captured screen. Baselines and comparison thresholds are unchanged.

Additional tests cover independent pass-screen presentation, superseded observer results, prediction failure/retry, cache preservation, deep-link routing and startup buffering, bounded chart-image retention, cancellable satellite search, the Sky Now LEO filter, and clearing propagation progress after an observer changes.

Final verification on iPhone 17 Pro / iOS 26.5:

- `python3 scripts/test-screens.py --behavior-only` builds successfully and passes all 38 behavior/integration tests.
- The full screenshot run passes 36 of 40 comparisons. The four remaining differences are the live MapKit globes in Pass Forecast and Mission Control, in light/dark mode, as documented above. The screenshot test method therefore still fails; no baselines or thresholds were changed.
- Simulator checks: native ISS pass list and chart, satellite-category loading and ISS search, Sky Now loading/propagation with the LEO filter, alarm scheduling and sheet dismissal, alarm persistence after a full app relaunch, and deletion back to an empty alarm list. No test alarm remains scheduled.
- Source, project, and package-lock searches find no SwiftRex, CombineRex, CombineRextensions, or legacy store/middleware protocol references. The Xcode project passes `plutil -lint`, and `git diff --check` is clean.

Simulator captures: [pass list](SimulatorChecks/native-pass-list.jpg), [chart](SimulatorChecks/native-pass-chart.jpg), [scheduled alarm](SimulatorChecks/native-alarm-scheduled.jpg), [restored alarm](SimulatorChecks/native-alarm-restored.jpg), [deleted alarm](SimulatorChecks/native-alarm-deleted.jpg), [satellite search](SimulatorChecks/native-satellite-search.jpg), and [Sky Now](SimulatorChecks/native-sky-now.jpg).

The simulator exposed failing TLS connections on the old `celestrak.com` category URLs. They now use the documented `celestrak.org` GP endpoint with an explicit TLE format ([CelesTrak documentation](https://celestrak.org/NORAD/documentation/gp-data-formats.php)). This retains the existing data format; adopting OMM for catalog identifiers beyond the TLE limit is a separate data-format migration.
