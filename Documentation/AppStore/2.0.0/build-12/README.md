# 2.0.0 build 12 — TestFlight preparation (September 25, 2026)

Source: `codex/observation-home` at the commit after f46f353 (version bump).
Marketing version 2.0.0, build 12, set on both the app and widget targets. The
`asc xcode version edit` command only updated the app target; the widget
extension's `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION` were aligned by
hand. Check both before archiving.

## Verification

- `python3 scripts/test-screens.py --behavior-only --simulator 0D39CA43-2212-46F4-AE51-A38A3DDDB9BC`:
  129 passed, 0 failed, 2 skipped ([behavior-tests.txt](behavior-tests.txt)).
  Without `--simulator`, the runner picked a destination that does not exist on
  this machine and reported zero tests; pass the booted iPhone 17 Pro Max UDID.
- Observation home, pass list, navigation and atmosphere review evidence lives
  under `Documentation/DesignReview/ObservationHome/`.

## Archive status

Archiving failed twice on signing. The widgets introduced the
`group.io.djben.SatelliteForecast` App Group entitlement on the app and the
widget extension, and the cached automatic profiles do not include it.
Xcode has no signed-in account (`No Accounts`), so `-allowProvisioningUpdates`
cannot regenerate them, and `io.djben.SatelliteForecast.Widget` is not yet a
registered bundle ID in App Store Connect. Resolution options are recorded in
the publishing guide. No IPA was produced and nothing was uploaded.

Test notes for the upload: [test-notes-en-US.txt](test-notes-en-US.txt).
