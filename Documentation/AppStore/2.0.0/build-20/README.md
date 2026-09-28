# 2.0.0 build 20 — latest-main replacement

Built from main `26d4767`, including the planetarium responsiveness fix, selected eye,
live pass arc and elevation, coral passing-now shimmer, debug clock support,
automatic Now mode during a pass, and remote Live Activity updates. The latest widget
fix caches forecasts for four recent places for seven days and shows live passes in coral.
Chinese installed and App Store names are **天宫过境**.

Build 16 was withdrawn. Builds 17–19 were uploaded but never submitted. Public release
remains manual. The submission result will be recorded after screenshot verification.

## Screenshots

Eight locales, six screenshots each, iPhone 17 Pro Max, dark mode, 1320 × 2868.
The 40 in-app slots were freshly regenerated during build 19 preparation and reviewed
individually; the build 20 follow-up changes widget caching and labels, leaving these
preview screens unchanged. Widget slots use the merged per-place cache implementation.
The pinned locale moments, orbital inputs, observers, and time zones are preserved.

Independent simulator clones avoid interference with other local builds. Capture
scripts follow the active per-place forecast index and verify the observer and a
fresh nonempty forecast before recording Home Screen widgets.

## Build verification

- 133 behavior tests passed, zero failed, two optional visual reviews skipped.
- Archive/export succeeded. Production APNs/App Attest and Chinese installed name
  verified in the exported IPA; its SHA-256 is recorded.
- Build `ca72ee89-33f3-43fa-b017-b2c9e1f00204` processed as VALID.
- Release preparation commit `18e3286` is on main.
- All eight screenshot selection records match the reviewed 1.7.1 moments exactly.

All 48 full-size screenshots were reviewed individually. The widget capture was split
between two independent simulators: en-US/fr-FR/es-ES/pt-BR on the first and
ru/ja/ko/zh-Hans on the second. The western runner was intentionally interrupted after
its four images were saved; its language-restoration error was resolved by rebooting
and restoring English. No placeholder or foreground-app image is in the final set.
The normal build 20 app was installed and relaunched in dark mode after testing.

## Screenshot upload

All 48 refreshed screenshots were uploaded in eight locales, ordered widgets first,
then forecast, planetarium, pass chart, pass list, and satellites. Each upload verified
Apple's COMPLETE state and ordered MD5 checksums. `screenshots-verified.log` records
the final read-only comparison across every locale.
