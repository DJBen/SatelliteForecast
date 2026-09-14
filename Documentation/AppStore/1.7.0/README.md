# App Store screenshots for 1.7.0

The existing App Store draft contained four `APP_IPHONE_67` images per locale at 1320 × 2868 pixels. `existing-inventory.json` records the original IDs, order, filenames, checksums, and Apple image URLs. The local `before/` directory is a backup of all 32 downloaded originals (excluded from Git); `index.html` compares each original with its replacement.

| Slot | Screen | Route |
| --- | --- | --- |
| 01 | Forecast overview | Pass forecast tab |
| 02 | Individual pass chart | Pass forecast → station → visible pass |
| 03 | Pass list and globe | Pass forecast → station |
| 04 | Satellite categories | Satellites tab |

The original Japanese, Korean, and Simplified Chinese sets feature Tiangong in slots 02/03. English, French, Spanish, Brazilian Portuguese, and Russian feature the ISS. This choice and the slot order are preserved.

## Reproduce

Run `python3 scripts/capture-store-screenshots.py` from the repository root. Use `--locales en-US ja` for a locale subset or `--screens 03-pass-list` to recapture one slot. The default device is iPhone 17 Pro Max / iOS 26.5, with the same 1320 × 2868 output dimensions as the previous iPhone 16 Pro Max screenshots. Captures are native simulator PNGs, without resizing or compositing.

The hosted XCTest fixture supplies:

- A fixed instant, `2026-09-14T08:00:00Z`, and the America/Los_Angeles timezone.
- A fixed observer at 37.486743, −122.226560, altitude 0 km.
- Separate saved CelesTrak ISS and Tiangong TLEs with September 13, 2026 epochs, under `SatelliteForecastTests/Fixtures/AppStore/`.
- Real orbital propagation and pass selection from those TLEs. The chart uses the first visible pass, rather than an invented orbit or prediction.
- North-up chart orientation via the normal compass-off state. No physical sensor readings are required.
- Frozen video frames using the existing snapshot environment, plus fixed 9:41 status bar, battery and Wi-Fi indicators.
- Separate app launches for each locale, including Foundation language/region settings, in addition to SwiftUI locale and timezone values.

The test exposes each completed screen through a ready/acknowledgement file. The CLI captures the simulator display and checks the PNG signature and exact dimensions before acknowledging it. The regular regression snapshots use a separate directory and are not rerecorded by this workflow. MapKit still downloads real map tiles; the map camera/clock are fixed, but Apple imagery is not guaranteed to be byte-identical between runs. Visually inspect the globe before upload.

## Replace draft screenshots

Review `index.html`, then run `python3 scripts/replace-store-screenshots.py` for validation only. Add `--apply` to upload the reviewed replacements. The script checks all locales before mutation, requires the draft to remain in `PREPARE_FOR_SUBMISSION`, rejects unexpected remote changes, and verifies screenshot order, checksums, and Apple's `COMPLETE` delivery state. It targets only the version and existing display type in the inventory.

If restoration is needed, upload the local `before/<locale>/` PNGs with `asc screenshots upload --version-localization <inventory localizationId> --path <backup directory> --device-type APP_IPHONE_67 --replace`.

## App fixes found during capture

The graph footer previously mixed a 24-hour clock with AM/PM, producing labels such as “19:00 PM.” It now uses SwiftUI's locale-aware hour/minute format. The overview heading now reuses the existing localized forecast-tab label. These fixes are included in the replacement 1.7.0 build so store images match the binary. Brazilian Portuguese now translates “Evening,” and pass-card dates fall back to a compact localized numeric format when the longer date cannot fit. The compass's initial state is injectable for fixtures; its production default remains enabled.

## Validation

- All eight locale capture tests passed on iPhone 17 Pro Max / iOS 26.5; all 32 native PNGs were visually reviewed.
- The 38 behavior tests passed on iPhone 17 Pro / iOS 26.5.
- `capture-checksums.json` records dimensions and hashes of the final images. `upload-results.json` records Apple's replacement asset IDs.
- The test plan was restored after capture. Existing regression baseline images were not modified.
- Release archive and export succeeded for `io.djben.SatelliteForecast`, version 1.7.0, build 2.
- All 32 replacement assets reached Apple’s `COMPLETE` state; remote order and MD5 checksums match the local files. The public App Store version remains a draft.
