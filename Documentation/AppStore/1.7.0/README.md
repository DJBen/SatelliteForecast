# App Store screenshots and release 1.7.0 (build 4)

## Marketing choices

The previous captures chose the first visible pass: ISS at 17° and Tiangong at 28°. The original 2025 ISS screenshot had a stronger 47° illuminated arc and showed a shadow transition. The new set keeps that emphasis on useful observing information while showing the redesigned sky chart, Milky Way, event timeline, station cards, pass list, and satellite catalog.

The new fixture starts September 9, 2026 at 18:00 America/Los_Angeles (`2026-09-10T01:00:00Z`), at the same observer (37.486743, −122.226560). It uses the saved September 13 ISS and Tiangong TLEs and the app's real propagation, with no fabricated passes. These are reproducible illustrative captures using historical orbital data, not live forecasts.

For the detail screen, choose the highest illuminated visible pass with the Sun below −10°. This selects ISS on September 9 at about 20:34 (56°) and Tiangong on September 10 at about 20:27 (87°). The higher 84° ISS candidate was rejected because twilight caused the app to hide its stars. The overview and pass list retain chronological predictions. The fixture's prominent-pass threshold matches production at greater than 45°.

## Screens and languages

| Slot | Screen |
| --- | --- |
| 01 | Forecast overview |
| 02 | Individual pass and event timeline |
| 03 | Pass list and globe |
| 04 | Satellite categories |

English, French, Spanish, Brazilian Portuguese and Russian feature ISS. Japanese, Korean and Simplified Chinese feature Tiangong. All captures are native 1320 × 2868 simulator PNGs for the existing `APP_IPHONE_67` slot, without resizing or marketing composites.

`index.html` compares the original store set, the previous capture, and this set. `before/` and `round-2/` are local image backups excluded from Git; previous captures also remain in Git history. `original-inventory.json` preserves the initial store inventory; `existing-inventory.json` records the assets immediately before this replacement.

## Reproduce and upload

Run `python3 scripts/capture-store-screenshots.py`. Use `--locales en-US ja` or `--screens 02-pass-chart` for a subset. Captures use iPhone 17 Pro Max / iOS 26.5, fixed 9:41 status indicators, north-up compass-off charts, frozen video frames and separate language/region launches. The runner restores the test plan. Charts and maps get 15 seconds to settle; Apple map imagery is external and must be visually reviewed.

`python3 scripts/replace-store-screenshots.py` validates the assets. Add `--apply` to upload. The script requires the inventoried draft to remain `PREPARE_FOR_SUBMISSION`, checks for remote changes, and verifies Apple's delivery state, order and MD5 checksums. If an upload stops after a verified prefix of the new set, rerunning safely resumes with `--skip-existing`; unexpected remote changes still stop the run. `upload-results.json` and `capture-checksums.json` record delivery evidence.

## Matching app fix

Build 4 localizes the new Compass, Full screen, event names, azimuth and elevation labels in all eight store languages. The screenshot timing and selection changes are test-fixture-only. Build 3 was uploaded before visual review caught those missing translations; build 4 supersedes it.

## Validation and upload status

- All 55 behavior tests passed on iPhone 17 Pro / iOS 26.5.
- Release archive and IPA export succeeded for `io.djben.SatelliteForecast`, version 1.7.0, build 4.
- Build `88251915-ba75-4b29-b587-c889c3486c54` processed as `VALID`, is `IN_BETA_TESTING` internally, and is attached to the 1.7.0 App Store draft.
- All eight translation resource files passed `plutil -lint`.
- All eight localized capture tests passed. All 32 images were visually reviewed and verified at 1320 × 2868.
- All 32 replacement screenshots reached Apple's `COMPLETE` state, with remote order and MD5 checksums matching local files. The initial English upload stopped after two assets; the remaining two were resumed and the complete set reverified.
- `capture-checksums.json`, `upload-results.json` and `build-verification.json` retain the final evidence.
- The test plan was restored, regression snapshot baselines were not changed, and `git diff --check` passed.
- The App Store version remains `PREPARE_FOR_SUBMISSION`; build 4 and screenshots are uploaded without submitting the public release for review.
