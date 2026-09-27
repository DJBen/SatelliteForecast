# App Store Connect publishing guide

Read this before preparing any release. It is the consolidated procedure as of the 2.0.0
draft (September 27, 2026). Inspect the current remote state and the installed CLI help
before reusing a command; historical IDs in the evidence directories are records, not
targets. The guide is a procedure, not standing authorization to publish.

## Entry points

- App **Space Station Passes**, bundle `io.djben.SatelliteForecast`, App Store Connect app
  ID `1578649430`, team `52RD2GH5DP`. Project `SatelliteForecast.xcodeproj`, scheme
  `SatelliteForecastApp`.
- `asc` CLI for App Store Connect, authenticated through the System Keychain profile.
  Never copy keys or tokens into the repository. Working command names: `asc builds
  info`, `asc builds test-notes`, `asc testflight groups list`, `asc testflight
  distribution view`, `asc localizations list/update`, `asc screenshots list/upload`,
  `asc versions create/view/attach-build`, `asc validate`, `asc review submit`.
- Internal TestFlight group **First Light** `3b41d8f3-2916-4274-9506-6bcc7cd7ec20` has
  automatic access to all builds. External group **First External Light**
  `fe2fe77e-ebee-4d88-84c4-8225a55fe746` is assigned only when requested.
- Simulator for captures and behavior tests: iPhone 17 Pro Max, UDID
  `0D39CA43-2212-46F4-AE51-A38A3DDDB9BC`, iOS 27. Rediscover with
  `xcrun devicectl list devices` if it is missing.
- [Screenshot moments](ScreenshotMoments.md) holds the reviewed dates, observers, time
  zones and orbital inputs per locale, and describes each slot. Per-release evidence
  lives in `Documentation/AppStore/<VERSION>/` (and `<VERSION>/build-<N>/` for later
  builds of the same version).

## Release sequence

1. **Inspect.** `asc versions list --app 1578649430`, `asc builds list --app 1578649430`,
   `asc testflight groups list --app 1578649430`. Read the working tree; include the
   intended work without discarding unrelated changes. Behavior tests and the screenshot
   runner re-record some design-review PNGs; do not commit those with a release bump.
2. **Version and build.** `asc xcode version edit --project SatelliteForecast.xcodeproj
   --version <V> --build-number <N>` updates only the app target. Align the widget
   extension by hand and confirm four matching `MARKETING_VERSION` and
   `CURRENT_PROJECT_VERSION` entries in the pbxproj. Create the evidence directory.
3. **Behavior tests.** `python3 scripts/test-screens.py --behavior-only --simulator <UDID>`.
   Without `--simulator` the runner can pick a destination that is not installed and
   report zero tests with exit code 0. Read `Overall Result` and the counts, not the exit
   code. Transient star-catalog failures (`disk I/O error`, `InvalidTransition`) warrant a
   fresh rerun, never a relaxed assertion.
4. **Archive and export.** Both need `--xcodebuild-flag=-allowProvisioningUpdates` because
   the app and widget carry the `group.io.djben.SatelliteForecast` App Group, and Xcode
   must have account access; App Groups cannot be created through the public API. Keep
   archives and IPAs outside Git. The archive step may rewrite
   `Frameworks/SatelliteForecast/Package.resolved`; discard that unless the dependency
   change is intended.

   ```sh
   asc xcode archive --project SatelliteForecast.xcodeproj --scheme SatelliteForecastApp \
     --configuration Release --archive-path /tmp/SatelliteForecast-<V>-<N>.xcarchive \
     --xcodebuild-flag=-derivedDataPath --xcodebuild-flag=/tmp/SatelliteForecast-release-build \
     --xcodebuild-flag=-clonedSourcePackagesDirPath --xcodebuild-flag=<SourcePackages> \
     --xcodebuild-flag=-disableAutomaticPackageResolution \
     --xcodebuild-flag=-onlyUsePackageVersionsFromResolvedFile \
     --xcodebuild-flag=-skipPackageUpdates --xcodebuild-flag=-allowProvisioningUpdates
   asc xcode export --archive-path /tmp/SatelliteForecast-<V>-<N>.xcarchive \
     --export-options Documentation/AppStore/<V>/build-<N>/export-options.plist \
     --ipa-path /tmp/SatelliteForecast-<V>-<N>.ipa --xcodebuild-flag=-allowProvisioningUpdates
   ```

   Export options: method `app-store-connect`, `signingStyle` automatic, `teamID`
   `52RD2GH5DP`, `manageAppVersionAndBuildNumber` false, `uploadSymbols` true.
5. **TestFlight.** Upload once with `asc publish testflight --app 1578649430 --ipa … --version
   <V> --build-number <N> --group <FIRST_LIGHT> --test-notes "$(cat notes.txt)" --locale en-US
   --wait --timeout 30m`. "Skipped internal group … already receives all builds" is success.
   The post-upload wait can outlive its API token and end with an authentication error
   after "Upload committed": do **not** upload again. Confirm with `asc builds info --app
   1578649430 --build-number <N> --version <V> --platform IOS`, check `asc testflight
   distribution view --build-id <ID>` for `IN_BETA_TESTING`, and apply notes with
   `asc builds test-notes update --build-id <ID> --locale en-US --whats-new …` (`create` when
   no localization exists). Save the publish log and the final states.
6. **App Store draft.** `asc versions create --app 1578649430 --version <V> --platform IOS
   --copy-metadata-from <PREVIOUS> --exclude-fields whatsNew --release-type MANUAL` copies
   eight locales of metadata and inherits the previous screenshots. Write
   `release-notes.json` and apply each locale with `asc localizations update --version
   <VERSION_ID> --locale <L> --whats-new <TEXT>` from a subprocess argument list, then read
   the lengths back with `asc localizations list`.
7. **Inventory before touching screenshots.** Build a fresh `existing-inventory.json` from
   `asc localizations list --version <VERSION_ID>` and `asc screenshots list
   --version-localization <LOCALIZATION_ID>` per locale (see the 2.0.0 file for the
   schema: version id, `APP_IPHONE_67`, 1320 × 2868, and per-locale localization id, set
   id and ordered slot/id/fileName/checksum entries). Never reuse IDs from an earlier draft.
8. **Capture** (next section), review every full-size image, and only then run
   `python3 scripts/replace-store-screenshots.py --release-dir Documentation/AppStore/<V>`
   without `--apply` to validate, then with `--apply`. Inventoried slots must lead the local
   files in order; extra trailing slots are appended. The script only touches
   `PREPARE_FOR_SUBMISSION` drafts, waits for `COMPLETE`, and verifies ordered MD5 checksums.
   Rerun without `--apply` afterwards; every locale should print `already matches`.
   If the store order differs from the filename order (2.0.0 leads with the widget
   slot), record it in `slot-order.json` and use
   `python3 scripts/reorder-store-screenshots.py --release-dir … [--apply]` instead of
   the replace script; it uploads position-prefixed copies and verifies the remote
   order and checksums, and reports `already matches` when nothing changed.
9. **Attach and validate** when requested: `asc versions attach-build --version-id
   <VERSION_ID> --build <BUILD_ID>`, then `asc validate --app 1578649430 --version <V>`.
   The manual-release and App Privacy notices are informational.
10. **Submit** only when explicitly authorized: `asc review submit --app 1578649430
    --version-id <VERSION_ID> --build <BUILD_ID> --confirm`, then verify `asc versions
    view` and `asc review submissions-get`. WAITING_FOR_REVIEW is not a public release, and
    internal TestFlight availability is a separate status. To replace an approved but
    unreleased build, `asc submit cancel --version-id <VERSION_ID> --confirm` (legacy,
    without `--app`) moves the version to DEVELOPER_REJECTED; never use `versions release`
    as a workaround.
11. **Record.** Keep the selection JSONs, inventory, upload results, release notes, build
    identity, TestFlight states, validation and submission records, and a short README in
    the evidence directory. Restore the test plan (`git status SatelliteForecast.xctestplan`
    must be clean) and run `git diff --check`.

## Screenshot capture

Six slots per locale, dark mode only, iPhone 17 Pro Max at **1320 × 2868**
(`APP_IPHONE_67`), eight locales `en-US`, `fr-FR`, `es-ES`, `pt-BR`, `ru`, `ja`, `ko`,
`zh-Hans`. Always pass `--output` and `--release-dir`; the scripts still default to old
directories.

### In-app slots 01–05

```sh
python3 scripts/capture-store-screenshots.py \
  --output Documentation/AppStore/<V>/screenshots --derived-data <DerivedData>
# Retries: --locales en-US --screens 01-forecast 04-satellites
```

- The runner rewrites `SatelliteForecast.xctestplan` per locale (language, region and
  `STORE_SCREENSHOT_*` variables), runs `ScreenSnapshotTests.testAppStoreScreenshots`
  through `xcodebuildmcp simulator test`, and captures the real simulator screen on a
  ready/done handshake. Charts and maps get 15 seconds to settle. It restores the plan
  in `finally`; verify after an interruption.
- Slots: `01-forecast` observation home with the reviewed featured pass as the hero,
  `02-pass-chart`, `03-pass-list`, `04-satellites` with the station video cards on top,
  `05-planetarium`. `storeScreens` in `ScreenSnapshotTests.swift` builds them; the home
  uses a forecast model refreshed with the fixture passes, while the station cards use a
  separate unfiltered model so neither card reads "no visible pass".
- The snapshot environment freezes the home preview at 58% and skips the live preview
  loader, so `initialPreview` must be supplied.
- Do not run two test-plan-mutating runners at once. Use a separate derived-data path
  for read-only builds.

### Widget slot 06

```sh
python3 scripts/capture-widget-home-screenshots.py --output Documentation/AppStore/<V>/screenshots
```

- One-time simulator preparation: put the medium and large Space Station widgets alone
  on the **first** Home Screen page, in dark appearance. The widget gallery races the
  input tool, so add a short pause between taps.
- Per locale the script writes `AppleLanguages`/`AppleLocale` to `.GlobalPreferences`,
  sets the simulated location to the locale's observer, and reboots with
  `SIMCTL_CHILD_TZ=<zone>` in the boot environment, which is the only way found to give
  SpringBoard and the widget host the locale's time zone (`launchctl setenv` after boot
  does not reach them). It launches the app so the shared widget forecast is written,
  reboots again so SpringBoard opens on the first page (terminating the app lands on the
  page holding its icon, and restarting SpringBoard alone leaves the status bar blank),
  then overrides the status bar to 9:41 and captures.
- The widget content is the live forecast for that observer at capture time, not the
  historical moment; times and elevations differ between captures. Review each image for
  the station names, localized dates and the 24-hour clock in European locales.
- Two-row widgets (small "featured plus footer", medium list rows with the elevation on
  the arc) are documented with mockups in
  `Documentation/DesignReview/WidgetTwoRow-2026-09-27-mockups.html`; the locale matrix
  under `Documentation/WidgetPreviews/2026-09-27-two-row/` is the fit evidence.
- `WidgetStrings.text` must be offered both `fr_FR` and `fr-FR`; the underscore form alone
  makes every widget fall back to English. The widget extension's Info.plist also needs
  `CFBundleLocalizations` for the eight languages, or the widget name under each widget
  and the gallery entry stay in English.
- Use `--settle 50` when the simulated location changed; a shorter wait can leave the
  ISS row on "No visible pass" because the forecast had not finished for the new observer.

### Localization checks

- `python3 scripts/audit-localizations.py` lists keys missing per locale. Home strings
  added for 2.0.0 exist in all eight locales; a slot showing mixed languages means a
  string was added to `en.lproj` only.
- Keywords: include `iss` and `tiangong` everywhere, `天宫` first in Chinese, fields under
  100 characters; read remote values back after any change.
- Contact sheets (`ffmpeg hstack`) are review aids only; upload the untouched PNGs.

## Failure modes worth remembering

- **Exit codes lie.** XcodeBuildMCP and the screenshot runners can exit zero on failure;
  read the summaries and expected capture sequences.
- **MapKit is nondeterministic.** Inspect tile loading before blaming code, and do not
  relax unrelated snapshot assertions to hide it.
- **Full-screen video is invisible to `drawHierarchy`.** Capture the window for modal
  checks and assert `presentedViewController` separately.
- **Preference overrides.** Launch arguments such as `-hasCompletedAllPassesOnboarding NO`
  persist for that process and can invalidate "plays once" tests; use the Debug menu
  resets instead. `-debugMockedOffsetDays <days>` (Debug builds) shifts the mocked date
  when the simulator has no shake gesture.
- **Validation is not publication.** A clean `asc validate` and even a submission do not
  change what customers can download; report internal TestFlight, App Review and public
  release states separately and independently per build.

## Evidence index

- [2.0.0](2.0.0/README.md): observation home, push reminders, widgets; draft with six
  screenshot slots. Builds 12 and 13 on internal TestFlight.
- [1.9.0](1.9.0/README.md): TestFlight-only version bump (build 11).
- [1.8.0](1.8.0/README.md) and builds 7–10: planetarium release, external TestFlight,
  approved-build replacement.
- [1.7.1](1.7.1/README.md) and [1.7.0](1.7.0/README.md): first localized screenshot sets
  and the original capture lessons.
