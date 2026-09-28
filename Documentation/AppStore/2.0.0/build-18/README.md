# 2.0.0 build 18 — superseded before submission

Replaces build 16, withdrawn at the user's request. Includes remote Live Activity
updates, filled-eye selection, a live home pass trajectory and elevation label,
shared coral passing-now shimmer, debug-clock support and automatic Now mode in the
planetarium, plus the Moon-render cancellation fix already on main.

- Previous submission `aeb8e5df-463b-42e0-ba9c-407411320cd8` cancelled; version
  `a19adf2d-b230-4638-8989-cfbabb75d7c1` verified `DEVELOPER_REJECTED`.
- Behavior suite: 132 passed, 2 opt-in reviews skipped, no failures.
- Backend suite: 59 passed.
- Eight localized release notes include the new live-pass features. Support and
  marketing URLs now use the Firebase-hosted support website.
- Screenshots are regenerated from the pinned locale moments, dark mode,
  iPhone 17 Pro Max at 1320 × 2868. Six slots per locale, widget first.
- Release remains manual; App Review submission does not publish to customers.

Build `bf8639cb-481c-4e5e-8179-93b7c1bcb1b3` processed as `VALID` and is
`IN_BETA_TESTING` for the internal First Light group. It is attached to the editable
2.0.0 version. Validation returned zero errors and warnings; submission is pending
the final screenshot verification.

All eight in-app screenshot tests passed. Each pinned selection record matches the
reviewed 1.7.1 moment exactly. Widget captures wait for a fresh shared forecast and
for WidgetKit to finish rendering; earlier placeholder captures were discarded.

Build 17 was uploaded but not submitted. Build 18 also changes the Chinese installed app name and App Store name to 天宫过境. App UI captures started during build 17 preparation; their content is unchanged by the display-name-only update, and widget captures use build 18.

## Submission held

The user requested waiting for the concurrent widget setup/reset fix to merge into
`main`, then building and submitting the latest main. Build 18 was **not submitted**.
Its English and French screenshot sets were uploaded; the remaining widget captures
were stopped after simulator interference. A newer version-specific evidence folder
will hold the final candidate and fresh assets. Implementation commit `195a4cb` was
pushed to main before this hold.

The final replacement is [build 20](../build-20/README.md). The unfinished widget
images here are historical attempts, not the final reviewed upload set.
