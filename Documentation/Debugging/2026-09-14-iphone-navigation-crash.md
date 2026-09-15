# iPhone satellite navigation crash

## Evidence

Device report: `SatelliteForecastApp-2026-09-14-233815.ips`, September 14, 2026 at 23:38:15 PDT, iPhone OS 27.0, app 1.7.0 (2).

The main thread trapped with `EXC_BREAKPOINT / SIGTRAP` in Swift's `_assertionFailure`, called by `closure #1 in closure #2 in SatelliteListView.satellitesView(_:)`, then `LazyView.body`. UIKit was performing an interactive navigation transition (`_UINavigationParallaxTransition`, `UIPercentDrivenInteractiveTransition`).

The lazy destination force-unwrapped the current category, its loaded content, and the selected satellite. `SatelliteListView.task` calls `SatelliteListModel.load` whenever the list appears, which previously replaced loaded content with `.loading`. An interactive return transition can render the old destination while the parent reloads, making that forced lookup invalid. The report establishes the failing closure; the lifecycle sequence is inferred from the code and transition stack.

## Fix

- Resolve the destination against the immutable catalog snapshot used to build its rows.
- Handle an absent route ID without trapping.
- Remove the obsolete destination `onAppear` action, which performed another forced lookup even though the model ignores that action.
- Reuse an already loaded category when its list reappears. Explicit retry still forces a reload.

## Regression coverage

`ForecastTests.testSatelliteDestinationSurvivesCatalogReloadAndRemoval` renders the actual lazy destination after model data changes to loading or an empty catalog, and verifies it receives the original satellite. It also checks an unknown route ID.

`ForecastTests.testReturningToSatelliteListKeepsLoadedCatalogButRetryReloads` checks that returning preserves the catalog while explicit retry starts loading.

## Worktree

The isolated branch starts with a snapshot commit containing the original checkout's pending changes. The crash fix is a separate commit so it can be cherry-picked independently.

## Validation

- All 26 `ForecastTests` passed on iPhone 17 Pro Max simulator, iOS 26.5.
- Signed physical-device Debug build succeeded.
- Initial clean builds hit an Xcode package-resolver exception (`NSMutableArray insertObjects:atIndexes:`); retrying with `-disableAutomaticPackageResolution` succeeded. Resolved package-file churn is excluded from the fix.
- Installed the fixed build on the connected iPhone. Launch verification was blocked because the phone was locked; the physical-device navigation gesture has not been retested.
