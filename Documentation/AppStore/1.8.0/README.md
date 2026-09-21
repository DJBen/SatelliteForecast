# 1.8.0 draft preparation

Requested on September 19, 2026: build a new minor version, add a 3D-view screenshot, and keep the version in draft.

- App: Space Station Passes (`1578649430`, `io.djben.SatelliteForecast`).
- Draft version ID: `4e1c5986-0370-4294-a99d-8743fad7fb80`.
- Intended build: **1.8.0 (7)**. Release archive and IPA paths/checksum are in `build-evidence.json`.
- Release policy: **MANUAL**. No App Review submission or public release was requested or performed.
- Build 6 was uploaded before screenshot review found the Spanish Preview label truncated. Build 7 widens the time selector from 152 to 176 points; build 6 remains unattached.
- Eight localized release notes are in `release-notes.json`.
- Fifth screenshot: `05-planetarium.png`, native 1320 × 2868, dark mode. Each locale was captured in the real simulator and visually reviewed. Existing four screenshots are retained.
- All eight `selection-*.json` fixture records exactly match the reviewed 1.7.1 records; no observer, TLE, time-zone, or featured-pass changes.
- Validation: Release archive/export succeeded; simulator rebuilt and relaunched; behavior suite **95 passed, 0 failed, 2 skipped** (opt-in review tests). The eight store-capture runs each passed.
- No analytics events or measurement boundaries changed.

## Final verification

- Build `27d90055-94ab-48bd-bc3a-9c651d1f40ea` is **VALID** and attached to version 1.8.0.
- Version remains **PREPARE_FOR_SUBMISSION**; no submission exists.
- All eight locales have five screenshots in `APP_IPHONE_67`, all **COMPLETE**. The first four checksums match the initial inventory and the fifth matches its local PNG.
- App Store validation: **0 errors, 0 warnings, 0 blocking findings**. Informational items are manual release policy and the public API’s inability to verify App Privacy publication (recheck in ASC before any future submission).
- The archive retains the project's current iOS 26.0 deployment target.

See `final-version.json`, `build-processed.json`, `validation.json`, `final-screenshot-inventory.json`, and `screenshot-verification.log` for evidence.

## TestFlight distribution follow-up

User subsequently requested internal and external TestFlight distribution. Build 7 has localized What to Test notes in all eight locales; TestFlight validation passed with no errors/warnings.

- **First Light**: internal `IN_BETA_TESTING`. Group `3b41d8f3-2916-4274-9506-6bcc7cd7ec20` has access to all builds, so explicit assignment is neither needed nor accepted by Apple.
- **First External Light**: assigned group `fe2fe77e-ebee-4d88-84c4-8225a55fe746`; submitted for Beta App Review on September 19, 2026 at 10:00:54 PDT. State **WAITING_FOR_BETA_REVIEW**, with automatic tester notification enabled. External availability awaits Apple’s approval.
- Public TestFlight link: https://testflight.apple.com/join/ZJvjqV5N
- App Store version remains **PREPARE_FOR_SUBMISSION**. Beta review is separate from App Store review; no public-store submission was made.

## Build 8 follow-up

The user subsequently requested fresh localized pass/3D screenshots, installation on iPhone, and App Store review submission. See [build 8 evidence](build-8/README.md). Version 1.8.0 (8) is WAITING_FOR_REVIEW with MANUAL release; internal and external TestFlight are IN_BETA_TESTING. Earlier build 7 records above are historical.

## Build 10 review replacement

The user requested App Store review of the subsequent changes. The approved but unpublished build 8 was reopened and replaced by 1.8.0 (10), now WAITING_FOR_REVIEW with MANUAL release. See [build 10 evidence](build-10/README.md).
