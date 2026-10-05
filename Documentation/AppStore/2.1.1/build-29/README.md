# 2.1.1 build 29 release evidence

App 1578649430 (`io.djben.SatelliteForecast`), App Store version
`8f11c25d-5714-4753-957b-79d185c2632c`. Build 29 supersedes uploaded build 28
with the outlined Alarms tab icon fix for pushed navigation destinations.

## Current status

- IPA upload committed; processing verified VALID. Build ID `c84a5037-850c-40f5-9c52-5d402514c349`.
- Internal First Light TestFlight verified IN_BETA_TESTING on October 4, 2026.
- App Review submitted October 4, 2026 at 18:32:59 PDT; both version and review submission verified WAITING_FOR_REVIEW. Submission ID `6c0c289d-d5e9-40b6-98eb-baa866ef25cd`.
- Public version remains 2.1.0. New version uses manual release after approval.

## Changes

Dedicated Alarms tab, notification permission recovery, shared manual local alarm
editor with sound and wheel time picker, first upward 10° pass moment, simplified
alarm rows, glass Choose Pass button, bottom-right chart orientation guidance
with centered expansion and dismissal/suppression, and once-only Skychart video
on first Compass use from Passes or Satellites. Added control translations cover
eight locales. The native tab bar keeps the bell outlined when unselected and
filled when selected, including on pushed pass detail screens.

## Verification

- Full behavior suite: 167 passed, 3 optional review tests skipped, 0 failures.
- Localization audit clean for literal keys across eight languages.
- Release archive/export complete; app and widget both 2.1.1 (29).
- Simulator rebuilt and rerun in dark mode on iPhone 17 Pro Max. Native screenshots
  verify selected/unselected bell states.
- 32 freshly captured full-size store screenshots reviewed, 16 unchanged reviewed
  planetarium/widget images retained with source hashes. All 48 are 1320 × 2868.
  Eight selection JSONs exactly match the reviewed 2.0.0 build 20 pinned moments.
- Existing English “Peak elevation” captions in non-English pass lists are a
  localization follow-up. Direction subtitle truncation on long translations is
  existing behavior.
- Debug build 29 installed on Sihao’s iPhone; launch denied because the phone was
  locked. See device-install-retry.log and device-launch-retry.log.

## Records

`artifact.json` records archive, IPA identity and hashes. `publish.log` records the
committed upload; final build and distribution readbacks establish availability.
`release-notes.json`, `localizations-readback.json` and review contact preflight
record metadata. `screenshot-verification.json`, `inherited-screenshot-sources.json`,
`slot-order.json`, selection JSONs and screenshot upload logs record the gallery.
Final validation reports 0 errors, 0 warnings and 0 blocking issues (manual-release
and API privacy-state notices are informational). `submission.json`,
`version-submitted.json` and `review-submitted.json` establish App Review status.
`screenshot-final-check.log` confirms all eight ordered screenshot sets match the
local images with COMPLETE delivery. The test plan and package lock remain clean;
`git diff --check` passes.
