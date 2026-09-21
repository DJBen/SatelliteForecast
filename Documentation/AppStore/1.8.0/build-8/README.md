# 1.8.0 (8) release evidence

Build 8 includes the current authorized planetarium and typography work, built from the working tree at HEAD `ec055865a8354df6be1ff97e34d84b8e878f4322` plus uncommitted changes. See `build-identity.json` for archive identity and IPA checksum.

## Validation

- Release archive/export succeeded with pinned package resolution.
- iPhone 17 Pro Max, dark mode: 103 behavior tests, 101 passed, zero failed, two skipped.
- Release build installed on wired Sihao’s iPhone. Automatic launch was blocked because the phone was locked.
- Regenerated and visually reviewed pass-chart and planetarium native screenshots in all eight locales (16 refreshed images). Preserved the other three slots per locale. All eight selection JSONs exactly match the previous reviewed observing fixtures.
- All eight locale keyword fields already include `iss` and `tiangong`; no metadata edits were necessary.
- Existing Moon-selection issue was not reproduced; the hosted Moon-to-star selection regression passes. This release does not claim a fix for an unconfirmed cause.

## Submission

Submitted September 19, 2026 at 23:06 PDT (September 20 at 06:06 UTC). Both version and review submission report **WAITING_FOR_REVIEW**. Existing **MANUAL** release policy is preserved: this is not a public release.

- App Store version ID: `4e1c5986-0370-4294-a99d-8743fad7fb80`.
- Build ID: `9b3e6476-c6da-46ca-8d01-7156d6871454`, processing **VALID**, version 1.8.0, build 8.
- Review submission ID: `3d322c9b-2868-4e44-8607-e196fefa3dae`.
- Final validation: zero errors, warnings, or blockers. Informational notices only: manual release and privacy publication not verifiable through API. Submission succeeded.
- All 40 ordered screenshots remotely verified COMPLETE with matching MD5 checksums; 16 refreshed, 24 preserved.
- Internal and external TestFlight both **IN_BETA_TESTING**, auto-notification enabled. External group: First External Light. Localized What to Test notes populated in all eight locales.

See `version-final.json`, `review-final.json`, `testflight-final.json`, `validation-final.json`, and `screenshot-verification.log`.
