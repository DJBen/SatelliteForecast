# 2.0.0 build 13 — internal TestFlight (September 26, 2026)

Source: main at a9c68e7 plus the build number bump. Marketing version 2.0.0,
build 13 on the app and widget targets (the widget target was aligned by hand
again after `asc xcode version edit`).

Changes since build 12: dismissible Remind me row with the corner bell and the
denied-state Settings shortcut; shorter home sky with edge dissolves and the
rounded Moon halo; recorded ISS pass in the location prompt; station video
cards on the Satellites tab; labelled large widget chart with full station
names; dome arcs with lit and shadowed portions in the small and medium
widgets; and the trimmed chart mode buttons.

## Verification

- `python3 scripts/test-screens.py --behavior-only --simulator 0D39CA43-2212-46F4-AE51-A38A3DDDB9BC`:
  129 passed, 0 failed, 2 skipped ([behavior-tests.txt](behavior-tests.txt)).
- Widget previews and home review snapshots regenerated in dark mode during the
  day's work (`Documentation/WidgetPreviews/2026-09-26-events`,
  `Documentation/DesignReview/after`).

## Archive, export and upload

- Archive and export both used `--xcodebuild-flag=-allowProvisioningUpdates`
  and succeeded first time with the App Group profiles created for build 12.
- IPA: `/tmp/SatelliteForecast-2.0.0-13.ipa` (134,657,992 bytes), not stored in Git.
- `asc publish testflight` uploaded once ("Upload committed"). Its post-upload
  wait then failed with an expired API token ([publish-log.txt](publish-log.txt)),
  so the group step and test notes did not run inside that command. Inspection
  afterwards showed build `55cdcf90-ced8-4f92-a687-e66f179c1a26`,
  `processingState: VALID`, uploaded 2026-09-26 01:34 PDT.
- First Light receives all builds automatically: `internalBuildState:
  IN_BETA_TESTING`, `externalBuildState: READY_FOR_BETA_SUBMISSION`,
  `autoNotifyEnabled: true`.
- What to Test (en-US) was applied afterwards with `asc builds test-notes
  update --build-id …` from [test-notes-en-US.txt](test-notes-en-US.txt) and
  read back (623 characters).
- No App Store version, screenshot work, external testing or review submission
  was requested or performed. Internal TestFlight availability only.

Lesson: when `publish testflight --wait` dies with an authentication error
after "Upload committed", do not upload again. Check `asc builds info --app
1578649430 --build-number <N> --version <V> --platform IOS`, then finish the
distribution check and test notes with separate commands.
