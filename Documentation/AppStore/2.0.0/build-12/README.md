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

## Archive, export and upload (September 25, 2026, main at 289491c)

- Two archive attempts failed with `No Accounts` plus App Group profile errors
  (see the previous section of this file's history). A third attempt with
  `-allowProvisioningUpdates` succeeded once Xcode had account access: it
  registered `io.djben.SatelliteForecast.Widget`, enabled the
  `group.io.djben.SatelliteForecast` App Group, and generated development and
  store profiles for both targets. The export also needed
  `--xcodebuild-flag=-allowProvisioningUpdates` to create the store profiles.
- Archive: `/tmp/SatelliteForecast-2.0.0-12.xcarchive`; IPA:
  `/tmp/SatelliteForecast-2.0.0-12.ipa` (134,536,721 bytes). Not stored in Git.
- Upload: `asc publish testflight` with [test-notes-en-US.txt](test-notes-en-US.txt),
  log in [publish-log.txt](publish-log.txt). Build ID
  `cca96cc4-d976-48ca-933e-acb43c33d880`, `processingState: VALID`.
- Distribution: First Light receives all builds automatically (the "skipped"
  message). `asc testflight distribution view` reported
  `internalBuildState: IN_BETA_TESTING`, `externalBuildState:
  READY_FOR_BETA_SUBMISSION`, `autoNotifyEnabled: true`.
- No App Store version was created for 2.0.0 and nothing was submitted for
  review or external testing. Internal TestFlight availability only.
