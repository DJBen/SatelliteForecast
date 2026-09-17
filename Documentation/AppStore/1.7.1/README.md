# Version 1.7.1 (build 5)

This release adds localized geographic context, redesigned visible-pass rows and invisible-pass grids, compact-height layouts, and first-use glow guidance for the home screen and pass list. Chinese locales place Tiangong first. The first visible pass opens the existing sky-chart tutorial video.

## Screenshot selection

All screenshots are native dark-mode iPhone 17 Pro Max captures at 1320 × 2868, using the existing APP_IPHONE_67 slot. Four screens per locale: home, pass chart, pass list, and satellite categories.

The home captures use real propagated station positions close to recognizable places in each locale: California (English), France, Spain, São Paulo (Brazilian Portuguese), Russia, Japan, South Korea, and Anhui (Simplified Chinese, observed from Shanghai). Chinese features Tiangong; the other locales feature ISS. Selection checks the actual offline geographic result, not just a bounding box.

The pass screens use a separate real observing moment, chosen for a high illuminated elevation with the Sun below −10°. The pass list starts one hour before that selected pass. The saved September 13, 2026 TLEs and the app's normal propagation generate all positions and pass paths. These are reproducible illustrative captures, not live forecasts. Each locale uses a local observing site and time zone. `screenshots/selection-*.json` records the exact times, positions, and elevations.

## Reproduce

Run `python3 scripts/capture-store-screenshots.py --output Documentation/AppStore/1.7.1/screenshots`. Add `--locales en-US` or `--screens 02-pass-chart` for a subset. The runner restores the test plan after completion. Review MapKit output because its basemap tiles are external.

Run `python3 scripts/replace-store-screenshots.py --release-dir Documentation/AppStore/1.7.1` to validate the replacement. Add `--apply` after review. `--locales` limits the operation to already-reviewed sets. The upload script checks remote IDs before replacement and verifies image order, checksums, and Apple's COMPLETE delivery state.

## Validation

- Release archive and IPA export succeeded for 1.7.1 (5).
- All 59 behavior tests passed.
- Build `fedcf591-89fd-4ea8-ac4b-68a68b9b3e74` processed as VALID and is IN_BETA_TESTING for internal testing.
- Eight localized release notes are saved in `release-notes.json`.
- App Store version: `793583a0-c404-43d4-abef-34c034f6f77b`, configured for automatic release after approval.

## Selected passes

| Locale | Station | Peak illuminated elevation |
| --- | --- | --- |
| en-US | ISS | 56° |
| fr-FR | ISS | 71° |
| es-ES | ISS | 83° |
| pt-BR | ISS | 46° |
| ru | ISS | 74° |
| ja | ISS | 60° |
| ko | ISS | 86° |
| zh-Hans | Tiangong | 57° |

All eight localized capture tests passed. All 32 PNGs were visually reviewed in dark mode and verified at the required native dimensions.

## Final delivery status

- All 32 replacement screenshots are COMPLETE at Apple, with remote order and MD5 checksums matching the reviewed local PNGs.
- Final App Store validation: zero errors, zero warnings, zero blocking checks.
- Submitted on September 16, 2026 at 10:14 UTC. Version and review submission both report WAITING_FOR_REVIEW. Automatic release after approval is configured.
- Review submission ID: `5292078c-9c58-4eb8-8a8a-656dec0b968e`.
- Internal TestFlight: IN_BETA_TESTING; the First Light internal group automatically receives the build. External TestFlight was not requested.
- The test plan was restored and `git diff --check` passed.

## Keyword update and resubmission

- All eight locales now include `iss` and `tiangong`; Simplified Chinese starts with `天宫` and also includes `国际空间站`. Remote values were read back and verified in `keywords-verified.json`.
- Following the keyword update, validation again reported zero errors, warnings, and blocking checks (`validation-after-keywords.json`).
- Resubmitted the same 1.7.1 (5) build on September 17, 2026 at 05:06:26 UTC. The verified version state is WAITING_FOR_REVIEW (`version-after-keywords.json`).
- Current review submission ID: `10e9f82f-e72c-4201-bf87-7a165b87d4ed`; evidence is saved in `submission-after-keywords.json`. This supersedes the original submission above.
