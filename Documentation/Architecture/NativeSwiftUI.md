# Native SwiftUI migration

The target architecture uses SwiftUI views, feature-owned Observation models, plain Swift domain logic, and explicitly injected services. No replacement architecture framework is being introduced.

## First migration slice: Settings and the root view

- `AppSettings` is a main-actor Observation model owned by the loaded application view. Settings, root tab visibility, and the night overlay read the same instance. The two options remain session-scoped, preserving existing behavior.
- `SettingsOverviewViewImpl` owns its navigation path with SwiftUI State. It receives settings and ordinary closures that construct its child views. Its action enum, projected view state, reducer, and reducer wiring are removed.
- `RootView` receives a native tab Binding, settings, and view-building closures. It does not import SwiftRex, CombineRex, or CombineRextensions.
- `LegacyRootView` temporarily translates the existing tab store into that Binding. Keeping the existing tab action preserves the Sky Now loading effect and navigation consumers in features that have not yet migrated.
- Settings composition still constructs legacy location and alarm destinations. Those dependencies are confined to the wiring target; their services and view implementations have not yet migrated.
- Location selection changes domain state; the presented location view dismisses itself through SwiftUI. The reducer no longer pops a global Settings path, including when an action arrives with no location screen presented.

## Next slices

1. **Completed:** move location and alarm screen state behind native interfaces, preserving shared location and notification behavior. Location search uses cancellation-aware async work with overlapping-request tests. Shared location and notification services still use the legacy store until their consumers migrate.
2. Migrate Forecast state and loading to a main-actor feature model. Inject the prediction/catalog services and time source. Test cancellation, stale results, failures, and location changes before replacing the middleware chain.
3. Move Sky calculations and bounded render caches into services with explicit execution and isolation boundaries. Profile CPU work, main-thread responsiveness, and memory.
4. Migrate remaining navigation, onboarding, application lifecycle, debug, and notification coordination. Delete each obsolete action/reducer/adapter as its consumers move.
5. Remove the global store and the SwiftRex/CombineRex/CombineRextensions package products only after their final consumers are gone. Enable complete concurrency checking and Swift 6 language mode incrementally per target.

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
