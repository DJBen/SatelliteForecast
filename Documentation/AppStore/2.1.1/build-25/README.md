# iOS 2.1.1 build 25 — internal TestFlight

The user requested an internal TestFlight build for testing manual local pass alarms.
Build **25** (`4d159ed5-2846-413e-bfb7-84f35dc38e00`) is **VALID** and available to the
internal **First Light** group with **IN_BETA_TESTING** verified on October 4, 2026.
Export uses `testFlightInternalTestingOnly=true`; the external build state is
**NOT_APPLICABLE**. English What to Test notes were read back and match the saved text.
No external group was assigned and no App Store draft or submission was created.
The public App Store release remains 2.1.0.

## Included work

- The pass-detail top-right control opens the manual local alarm form for any pass.
- The alarm icon fills when a local alarm exists and opens that alarm for deletion.
- Local notification content includes the default notification sound.
- The new control labels and sound explanation are translated in all eight locales.
- Includes existing checkout UX edits to forecast alerts, compact pass rows, chart
  guidance, the empty alarm list, and asynchronous alarm-form saving/error handling.

## Validation

- Behavior tests: **154 passed, 0 failed, 3 optional fixtures skipped** (157 total).
- Normal Debug build 25 rebuilt, installed and launched on iPhone 17 Pro Max/iOS 27.
- Pass detail and alarm form visually reviewed in dark mode; PNGs and UI snapshots
  are in `visual-review/`. These are development evidence, not store screenshots.
- Denied notification permission was exercised before release preparation. The
  simulator notification toggle did not respond to automation, so successful sound
  delivery and the saved icon state require phone testing.
- Localization audit reports 16 pre-existing missing UX string references. The
  three new manual-alarm strings exist in all eight catalogs.
- App and widget archive/IPA identities match **2.1.1 (25)**. Archive/export succeeded.
- Test-generated design review assets restored; test plan and dependency pins preserved.

## Evidence

`preflight-*.json` records current remote versions, builds, and groups. The preflight
confirmed public 2.1.0 was READY_FOR_SALE / READY_FOR_DISTRIBUTION on October 4, 2026.
`source.diff` records the pre-bump checkout, `archived-source.diff` includes the version
bump, and `source-head.txt` identifies HEAD. The source includes uncommitted changes.
`export-options.plist`, `archive-identity.json`, `ipa-identity.json`, and build logs
record packaging. The archive and 130 MB IPA are outside Git under `/tmp/`.
`publish.log` records the single upload; an AWAITING_UPLOAD export placeholder in
`upload-state.json` is separate from the uploaded PROCESSING record.
`test-notes.txt` contains the What to Test instructions. `build-info.json`,
`distribution.json`, and `test-notes-remote.json` verify final availability and notes.
