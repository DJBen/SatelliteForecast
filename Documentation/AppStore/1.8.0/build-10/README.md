# 1.8.0 (10) App Review resubmission

Includes stable star-label admission/collision hysteresis, 12 pt star names, 0.25-second quaternion smoothing for Follow Device, and uppercase constellation names in both charts.

105 behavior tests: 103 passed, zero failed, two opt-in integration tests skipped on iPhone 17 Pro Max simulator. Dark rendered screenshot reviewed after typography changes. Device-motion behavior is verified with synthetic sensor tests; the previous device installation included smoothing and smaller stars.

The previously approved build 8 was PENDING_DEVELOPER_RELEASE. Reopening for the explicitly requested new review used `asc submit cancel --version-id … --confirm` without `--app` (legacy endpoint) and changed the version to DEVELOPER_REJECTED. Modern review submission cancellation rejects COMPLETE submissions; deleting the approved review item also failed. No public release occurred.

Existing eight-locale release notes, keywords, and five screenshots per locale are preserved. All screenshots remain COMPLETE; ISS and Tiangong keywords verified everywhere. Current dark render evidence is in `visual-review/`. Reviewer notes explain the replacement and how to enter the planetarium.

Submitted September 20, 2026 at 14:02 PDT (21:02 UTC). Build ID: `e87cb28e-1dbd-47f7-b99d-a7a856949a09`. Review submission ID: `1fe9d4bc-674d-4bd3-a56a-5ff51c41d604`. Both version and submission report **WAITING_FOR_REVIEW**. MANUAL release policy is retained; this is not a public release.

The initial readiness check reported zero errors/warnings/blockers. The final preflight encountered a transient Apple subscription-group server error; the review submit command reported the same warning but successfully submitted. A subsequent complete validation found only the expected non-editable WAITING_FOR_REVIEW state plus the usual manual-release/privacy informational notices. See `validation-before.json`, `validation-after-submission.json`, and the authoritative version/review state records.

TestFlight localized notes updated for all eight locales; distribution states are recorded in `testflight-final.json`.
