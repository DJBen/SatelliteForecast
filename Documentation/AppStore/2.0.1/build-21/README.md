# 2.0.1 build 21

Source commit: `8b749fd48426ce537f27dbcfff200b73a5a215a6`.
Pull request: [#86](https://github.com/DJBen/SatelliteForecast/pull/86).

## Included changes

- Permanent second-tab Sky Now with a live 3D planetarium, passing-satellite
  selection, pan/zoom, device orientation, and location recovery. Sky Now has no
  Now/Preview switch; pass-detail playback controls remain available.
- Up to 100 bright LEO satellites, selected before metadata enrichment. The root
  retains the parsed catalog across tab changes with the original six-hour expiry.
- Fresh forecasts are reused on tab reentry. Cancellation stops unfinished
  catalog/prediction work, and Sky Now has its own orbital worker.
- Actor-isolated, read-only SQLite metadata loading with Swift 6 concurrency
  checking, bounded positive/negative caching, faster OMM epoch parsing, and the
  corrected SatCat inclination mapping. Existing lookup indexes are verified.
- App and widget both use version 2.0.1, build 21.

## Validation

- 143 behavior tests passed, zero failed, 3 optional visual reviews skipped.
- All 9 catalog tests passed, including concurrent readers, cancellation,
  cache bounds/eviction, query plans, and full decoding of both bundled tables.
- Localization audit passed across eight locales. Release preparation reused the
  existing observer-location translations and marked the FPS unit as verbatim.
- Normal app rebuilt and launched on iPhone 17 Pro Max / iOS 27 simulator; dark-mode
  launch screenshot reviewed. The [live Sky Now review](../../../DesignReview/SkyNow-2026-09-28/README.md)
  records the live-planetarium fixture used during implementation.
- Release archive/export succeeded. Exported app and widget version/build values,
  production APNs/App Attest, App Group, and code signature verified. IPA SHA-256
  and size are recorded in `ipa-verification.json`.
- Test-generated historical design-review images/metrics were restored. The test
  plan and dependency lockfiles were not changed by release preparation.

The archive and IPA are outside Git under `/tmp/SatelliteForecast-2.0.1-21.*`.
`archive.log.gz` preserves the complete build log. This release creates no new
store screenshots or locale moments; existing store assets were not modified.

## Distribution

Upload committed to App Store Connect. Final processing and internal availability
verification is pending. Intended audience: internal **First Light** group.
External TestFlight, App Review submission, and public release are separate actions.
At preflight, version 2.0.0 returned `READY_FOR_SALE` / `READY_FOR_DISTRIBUTION`.
