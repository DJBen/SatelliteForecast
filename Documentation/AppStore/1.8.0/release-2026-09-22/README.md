# 1.8.0 public release — September 22, 2026

The user authorized releasing the approved App Store version. Confirmed version
`4e1c5986-0370-4294-a99d-8743fad7fb80`, build 10
(`e87cb28e-1dbd-47f7-b99d-a7a856949a09`), was `PENDING_DEVELOPER_RELEASE`.

Ran `asc versions release --version-id 4e1c5986-0370-4294-a99d-8743fad7fb80 --confirm`.
Apple accepted the release request; the subsequent version read returned
`READY_FOR_DISTRIBUTION`. This is the App Store release, separate from TestFlight
availability and the earlier App Review submission. Storefront propagation was
not independently checked.

Evidence: `before.json`, `release-result.json`, and `after.json`.
