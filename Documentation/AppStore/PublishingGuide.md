# App Store Connect publishing guide

Read this before the next release. These are repository-specific lessons from 1.7.0 and 1.7.1, verified on September 16, 2026. Inspect current remote state and installed CLI help before reusing commands. Historical version, build, screenshot, and submission IDs are evidence, not targets for a new release.

## Entry points

- App: **Space Station Passes**, bundle `io.djben.SatelliteForecast`, App Store Connect app ID `1578649430`.
- Xcode project: `SatelliteForecast.xcodeproj`; scheme: `SatelliteForecastApp`; signing team: `52RD2GH5DP`.
- Use the installed `asc` CLI for App Store Connect. Authentication was available through System Keychain; do not copy keys or tokens into this repository. The default authentication profile’s name need not match this app. Always identify the app explicitly.
- Use `xcodebuildmcp` for simulator builds/tests; use `asc xcode archive` / `export` for release packaging. Consult the XcodeBuildMCP skill when doing simulator work.
- Internal TestFlight group: **First Light**, ID `efbbd3a8-bed3-4c94-9de3-0e268b5a0b34`. It automatically received all builds for 1.7.1. Recheck group settings; do not distribute to the separate external group unless requested.
- [Screenshot moments](ScreenshotMoments.md) records exact UTC dates, local times, observing locations, time zones, orbital inputs, and reasons for the selections.
- [1.7.1 release evidence](1.7.1/README.md) contains the successful build, screenshot, validation, and submission records. [1.7.0](1.7.0/README.md) records earlier capture and upload lessons.

## Release sequence

1. Inspect `asc auth status`, `asc versions list --app 1578649430`, `asc builds list --app 1578649430`, and `asc testflight groups list --app 1578649430`. Read the current working-tree diff; include the intended work without discarding unrelated changes. Check existing version state before creating a draft or trying to modify screenshots.
2. Set the requested marketing version and an unused build number with `asc xcode version edit --project SatelliteForecast.xcodeproj --version <VERSION> --build-number <BUILD>`. Version 1.7.1 used build 5. Create `Documentation/AppStore/<VERSION>/` for evidence and screenshots.
3. Create the new version with `asc versions create --app 1578649430 --version <VERSION> --platform IOS --copy-metadata-from <PREVIOUS_VERSION> --exclude-fields whatsNew --release-type <POLICY>`. Use the release policy requested by the user; 1.7.1 used `AFTER_APPROVAL`. Copying metadata populated eight locales, and Apple also provided inherited screenshots. Inspect rather than assuming inheritance.
4. Write accurate release notes for every configured locale. Save them as `release-notes.json`, then apply with `asc localizations update --version <VERSION_ID> --locale <LOCALE> --whats-new <TEXT>`. Use structured subprocess argument lists for multiline translations, not shell-interpolated text. Preserve unrelated metadata.
5. Run behavior tests and review the changed screens in dark mode. `python3 scripts/test-screens.py --behavior-only` is the normal entry point. The 1.7.1 release passed 59 behavior tests. Screenshot fixture edits also need compilation: an old `storeScreens` call site initially failed when its new parameter had no default.
6. Archive and export the exact intended source/version. Use pinned package resolution flags to avoid silently changing dependencies. Keep archives and IPAs outside Git; record build identity and paths in the release notes.
7. When publishing is authorized, upload once and wait for processing. Distribute to the requested internal group, then verify **VALID** and **IN_BETA_TESTING**. Upload acceptance alone does not mean the build is ready.
8. Capture, visually review, and replace the screenshots following the section below. Prepare all local work before any confirmation that is actually required; do not add a confirmation step when the user already requested publication.
9. Attach the processed build: `asc versions attach-build --version-id <VERSION_ID> --build <BUILD_ID>`. Run `asc validate --app 1578649430 --version <VERSION>` after all assets finish processing. Resolve blocking findings.
10. For an already-uploaded, prepared build, submit with `asc review submit --app 1578649430 --version-id <VERSION_ID> --build <BUILD_ID> --confirm` when authorized. This avoids uploading the same IPA again through a combined publish command. Verify both `asc versions view --version-id <VERSION_ID>` and `asc review submissions-get --id <SUBMISSION_ID>` afterward.
11. Save the final remote state and summarize it accurately: **WAITING_FOR_REVIEW is not publicly released**. Automatic release after approval still depends on Apple’s review. Internal TestFlight availability is a separate status.

The guide is a procedure, not standing authorization to publish a future version.

## Archive, export, and internal TestFlight

Substitute the current version/build and paths; do not reuse an old archive accidentally.

```sh
asc xcode archive --project SatelliteForecast.xcodeproj \
  --scheme SatelliteForecastApp --configuration Release \
  --archive-path /tmp/SatelliteForecast-<VERSION>-<BUILD>.xcarchive \
  --xcodebuild-flag=-derivedDataPath \
  --xcodebuild-flag=/tmp/SatelliteForecast-release-build \
  --xcodebuild-flag=-disableAutomaticPackageResolution \
  --xcodebuild-flag=-onlyUsePackageVersionsFromResolvedFile \
  --xcodebuild-flag=-skipPackageUpdates

asc xcode export --archive-path /tmp/SatelliteForecast-<VERSION>-<BUILD>.xcarchive \
  --export-options <EXPORT_OPTIONS_PLIST> \
  --ipa-path /tmp/SatelliteForecast-<VERSION>-<BUILD>.ipa

asc publish testflight --app 1578649430 \
  --ipa /tmp/SatelliteForecast-<VERSION>-<BUILD>.ipa \
  --version <VERSION> --build-number <BUILD> \
  --group efbbd3a8-bed3-4c94-9de3-0e268b5a0b34 \
  --test-notes <WHAT_TO_TEST> --locale en-US --wait --timeout 30m
```

Create the export-options plist from these known working settings instead of depending on a surviving `/tmp` file:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>method</key><string>app-store-connect</string>
  <key>signingStyle</key><string>automatic</string>
  <key>teamID</key><string>52RD2GH5DP</string>
  <key>manageAppVersionAndBuildNumber</key><false/>
  <key>uploadSymbols</key><true/>
</dict></plist>
```

Apple took several minutes to expose/process 1.7.1 after “Upload committed.” Do not upload duplicates while waiting. A message saying the internal group was “skipped because it already receives all builds” was successful automatic distribution, not a failure. Confirm with `asc testflight distribution view --build-id <BUILD_ID>`; 1.7.1 reported `internalBuildState: IN_BETA_TESTING`.

## Localized screenshot workflow

- **Dark mode only**, unless the user explicitly requests otherwise. Do not spend release time capturing or fixing light-mode appearance.
- Keyword preference: include `iss` and `tiangong` in every locale. In Chinese, put localized `天宫` first; retain the Latin aliases too. Keep fields within 100 characters, preserve existing useful terms where possible, and read back the remote values after updating. The 1.7.1 update removed Spanish `órbita` to make room.
- Existing store locales: `en-US`, `fr-FR`, `es-ES`, `pt-BR`, `ru`, `ja`, `ko`, `zh-Hans`. Use exact App Store Connect locale identifiers.
- Current slots: `01-forecast`, `02-pass-chart`, `03-pass-list`, `04-satellites`. Four native PNGs per locale, 32 total. The successful device/slot combination was iPhone 17 Pro Max, **1320 × 2868**, **APP_IPHONE_67**, on iOS 26.5. Verify current device support and dimensions if changing simulators.
- The local simulator UUID used was `5D6FFD0C-6B24-4F95-8E94-B7F3EBD22FDB`; rediscover it if unavailable. Boot it and set dark appearance first. The capture runner sets 9:41 status indicators and clears the override afterward.
- `scripts/capture-store-screenshots.py` launches each language/region separately. SwiftUI `.locale` alone does not localize existing `NSLocalizedString` calls and can produce mixed-language previews. Use the full runner for store captures.
- The actual simulator screen is captured, including status and floating tab bars; do not substitute a resized hosted view. Wait for the ready/done handshake. Maps and charts receive 15 seconds to settle; native view snapshots alone do not prove the store image is complete.
- Suppress completed onboarding for store captures. Keep north-up, compass-off charts, deterministic orbital time, and fixed video frames. Review every locale for title wrapping, text clipping, missing maps/stars, correct country flag, station order, and pass quality. Contact sheets are review aids; upload the untouched full-resolution PNGs.

**Always pass the destination explicitly.** Both scripts still default to the old 1.7.0 directory as of this guide; omitting these flags can overwrite prior release artifacts:

```sh
python3 scripts/capture-store-screenshots.py \
  --output Documentation/AppStore/<VERSION>/screenshots

# Targeted retries or a first-locale review:
python3 scripts/capture-store-screenshots.py --locales en-US \
  --screens 01-forecast 02-pass-chart \
  --output Documentation/AppStore/<VERSION>/screenshots

python3 scripts/replace-store-screenshots.py \
  --release-dir Documentation/AppStore/<VERSION>

# Upload only reviewed sets; omit --locales once all sets are ready:
python3 scripts/replace-store-screenshots.py \
  --release-dir Documentation/AppStore/<VERSION> --locales en-US --apply
```

### Inventory before replacement

Create a **fresh** `existing-inventory.json` for the new draft. Use `asc localizations list --version <VERSION_ID>` and `asc screenshots list --version-localization <LOCALIZATION_ID>` for each locale. See [1.7.1’s schema/example](1.7.1/existing-inventory.json): app/version IDs, display type, width/height, and a `locales` map containing localization/set IDs and four screenshot entries (`slot`, remote `id`, filename, checksum) in order. Do not reuse 1.7.1’s IDs for a new draft. The current replacement script expects one existing inventoried image set per locale; if the new draft has no inherited set, handle initial upload explicitly rather than fabricating inventory IDs.

The script only modifies `PREPARE_FOR_SUBMISSION` drafts. It checks the inventoried remote IDs, requires valid PNG dimensions and slot order, and verifies Apple’s **COMPLETE** processing state plus the ordered MD5 checksums. An interrupted upload in 1.7.0 left a verified prefix; the script supports resuming that prefix with `--skip-existing`. Unexpected remote changes require a new inspection, not blindly deleting assets.

Upload locale subsets sequentially when using the same release directory: each invocation updates the shared `upload-results.json`. Capture remaining locales while uploading already-reviewed sets if useful. Before submitting, rerun validation across **all eight locales**; each should report `already matches`. After submission locks the draft, this script deliberately refuses to operate, so retain the pre-submission verification report.

## Failure modes and verification lessons

- **CLI exit code can be misleading.** XcodeBuildMCP sometimes exits zero despite test failures. Inspect `Overall Result`, failed counts, error text, and expected capture sequence. Existing runners check common failure text as well as the process result.
- **Do not run two test-plan-mutating runners together.** They temporarily rewrite `SatelliteForecast.xctestplan` and restore it in `finally`. After interruption, verify restoration explicitly. Read-only builds can use separate derived-data paths; avoid simultaneous writes to one build database.
- **Transient star-catalog failures occurred** (`disk I/O error (code: 10)`, `InvalidTransition … failed(deinit)`). A targeted rerun in a fresh test process succeeded. Never treat the failed run as a pass; investigate further if it repeats. Do not erase user simulator data or weaken assertions just to hide the failure.
- **Snapshot host vs modal:** `host.view.drawHierarchy` misses a presented full-screen video. Capture the window for modal checks and assert `presentedViewController` separately. Video frames are live, so verify presentation/first-use behavior instead of comparing arbitrary playback frames pixel-for-pixel.
- **Preference reset for live inspection:** passing `-hasCompletedAllPassesOnboarding NO` as a launch argument overrides persisted preferences for that process and can invalidate a “plays only once” test. Use the app’s Debug reset options to inspect first-use behavior normally. Editing a preferences plist outside the app may be masked by cached preferences.
- **MapKit is nondeterministic.** Inspect tile loading and globe composition; previously documented map-only baseline differences also occurred on unchanged code. Do not relax unrelated screenshot assertions to mask them.
- **Validation is not publication.** The successful final 1.7.1 readiness result was zero errors/warnings/blockers, with one informational notice that App Privacy publication cannot be checked through the public API. Submission then succeeded. If Apple rejects a future submission, resolve the actual response rather than assuming an informational notice is harmless or blocking.
- Current command names that worked: `asc testflight groups list` (not `beta-groups`), `asc builds info` (not `builds view`), and `xcodebuildmcp simulator build-and-run` / `test` / `install`. Discover `--help` if an installed version changes. `snapshot-ui` also encountered a CLI next-step formatting error in this environment; actual simulator screenshots remained usable.

## Evidence to retain per version

Keep the reviewed native captures, exact selection JSONs, local checksums, pre-upload inventory, upload results, localized release notes, build identity, internal TestFlight state, final validation, submission ID/date, final version/review state, and a concise README. Restore the test plan and run `git diff --check`. Do not store credentials. Temporary archive, log, and helper paths are not durable documentation; preserve the facts and reproducible commands in the repository.

## 1.8.0 draft preparation notes (September 19, 2026)

- A draft-only request authorizes creating the version, uploading/attaching its build, and adding screenshots, but not App Review submission. Use `MANUAL` release and verify `PREPARE_FOR_SUBMISSION` afterward.
- `asc versions create --copy-metadata-from 1.7.1` inherited all four screenshots in each of eight locales. Inventory first; append `05-planetarium.png` without `--replace` to preserve those reviewed assets.
- The capture runner supports `05-planetarium` and `--derived-data`. Old `/tmp` dependency checkouts may have been removed. Use a populated DerivedData cache, or pass `-clonedSourcePackagesDirPath` for archiving, while retaining all pinned-resolution flags.
- Current internal group is `First Light` (`3b41d8f3-2916-4274-9506-6bcc7cd7ec20`); historical group IDs above must not be reused without inspection. Draft preparation uses `asc builds upload`, with no explicit group distribution or review submission.

### Internal and external TestFlight follow-up

For 1.8.0 (7), the user subsequently authorized both groups. Read group settings first: `First Light` has `hasAccessToAllBuilds: true`; explicit assignment returned “Cannot add internal group to a build,” while the build was already `IN_BETA_TESTING`. Assign only the external group with `asc builds add-groups --build-id <BUILD_ID> --group <EXTERNAL_GROUP_ID> --submit --confirm`. Fill the existing empty en-US What to Test localization using `update`, and create the other locales before submitting. Verify `autoNotifyEnabled`, external beta-review state, and that the App Store version remains in draft when requested. `WAITING_FOR_BETA_REVIEW` is not yet external tester availability.

### 1.8.0 build 8 review submission follow-up

The user later authorized App Store review submission and a new on-device build. Retain build 7 evidence and use `1.8.0/build-8/` explicitly for refreshed captures, inventory, uploads, and validation. The screenshot replacement script now derives the expected asset count from inventory (five for 1.8.0), including processing-state and checksum checks. Refresh slots `02-pass-chart` and `05-planetarium` together in all eight locales; preserve the other three reviewed slots. Verify both `iss` and `tiangong` remotely before changing keywords—build 8 preparation found both already present everywhere. Keep the existing MANUAL release policy unless the user asks to change it.

Build 8 submission succeeded with the same two informational validation notices (manual release and privacy API limitation). Both version and submission returned WAITING_FOR_REVIEW. TestFlight returned IN_BETA_TESTING for both internal and external distribution after submitting the new build. Verify these states independently for each build; do not infer beta availability from App Review submission.

### Build 9 stability follow-up

When a user requests a new TestFlight build while the previous App Store build is already IN_REVIEW, uploading the new build need not interrupt that review. Keep separate build-specific evidence and report the TestFlight and App Store versions distinctly. Build 9 contains temporal star-label admission and collision hysteresis; its test evidence and localized What to Test notes are under `1.8.0/build-9/`.

### Replacing an approved, unreleased build

For 1.8.0 build 10, the user authorized resubmitting the latest changes while build 8 was PENDING_DEVELOPER_RELEASE. `review submissions-cancel` rejected the COMPLETE submission, and removing its approved review item returned not found. The legacy `asc submit cancel --version-id <VERSION_ID> --confirm` **without `--app`** succeeded, moving the version to DEVELOPER_REJECTED and permitting a new build selection. Preserve MANUAL release, metadata, and screenshots; submit the newly processed build for a fresh review. Do not use `versions release` to make an old build public as a workaround.

### 1.9.0 TestFlight preparation

A TestFlight-only version bump can upload a new marketing version while 1.8.0
remains WAITING_FOR_REVIEW. No App Store draft or screenshot replacement is
needed for that request. Build 11 uses marketing version 1.9.0 and the current
internal First Light group with automatic access to all builds.

Close-zoom star fixtures must precess J2000 catalog coordinates to the simulated
date before passing them to `azel`; otherwise the test camera can miss its
target after the renderer's precession correction. Retain the initial failed
run and the corrected full behavior run as separate evidence.
