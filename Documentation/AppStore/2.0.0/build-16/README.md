# 2.0.0 build 16 — App Review submission (September 27, 2026)

Widget refinements on top of build 15: medium widget margins (10 pt top and bottom
instead of the system inset), the small chart restyled after the two-row small, the
large widget header with icon, compact name and day line, inward placement of colliding
chart labels, and the shortened Russian "tonight".

- Build `adb91e16-4aec-41c8-a41f-c7dc06880d6d`, uploaded 2026-09-27 08:04 PDT, VALID,
  IN_BETA_TESTING on First Light ([publish-log.txt](publish-log.txt),
  [test-notes-en-US.txt](test-notes-en-US.txt)).
- Behavior suite: 129 passed, 0 failed, 2 skipped ([behavior-tests.txt](behavior-tests.txt)).
  Widget locale matrix: 48 renders inside bounds.
- Attached to version `a19adf2d-b230-4638-8989-cfbabb75d7c1` ([attach-build.json](attach-build.json)).
- `asc validate`: 0 errors, 0 warnings, 0 blockers, 2 informational notices (manual
  release; App Privacy state not verifiable via the API) ([validation-before.json](validation-before.json)).
- Submitted for review: submission `aeb8e5df-463b-42e0-ba9c-407411320cd8` at
  2026-09-27 15:10 UTC ([submission.json](submission.json)). Final states in
  [version-final.json](version-final.json) and [review-final.json](review-final.json).
- Release type remains MANUAL: approval does not publish; release with
  `asc versions release --version-id … --confirm` when ready.

Draft screenshots (six per locale, widget slot first) were last refreshed with the
final widget layouts and verified before submission.
