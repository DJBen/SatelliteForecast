# iPhone Duo design review — October 3, 2026

Website: https://satellite-iphone-duo-review.swifty-ben.chatgpt.site

The new owner-private website contains 17 actual dark-mode outer-display captures, six prioritized UX recommendations, original PNGs, capture metadata, and interactive proposed arrangements for the inner flat, book, and tabletop poses.

## Verified evidence

- Actual iPhone Duo device type on iOS 27.1 beta (24A94401), using Xcode 27.1 beta (27A9269).
- Simulator: `7C40B063-AE4F-4981-9915-EDCD4DF343A5`.
- Native scene: 466 × 678 points; original screenshots: 1398 × 2034 pixels.
- App: 2.1.0 (24), commit `ed8180c3772b195bcc47d1aa497ae354df890bca`.
- Production view fixtures in a real UIWindowScene. No fixed phone frame is assigned. A unique view identity resets each screen and text-size variant.
- Fixtures use English, UTC, a frozen orbital epoch, and a test observer. These are layout evidence, not validation of live data, notification delivery, permissions, or sensor accuracy.
- Standard text plus accessibility2 variants for home, pass reminder, and the fixed-compass chart.
- Capture harness test completed successfully. The temporary test method and test-plan environment additions have been restored.

## Review priorities

1. Stack reminder event labels and times at accessibility text sizes; keep scheduling reachable.
2. Move the motion guidance away from the chart’s pass path and keep a fixed-chart fallback.
3. Lead with compact upcoming-pass rows; make the globe secondary.
4. Clarify the scope and create/edit wording of reminders and confirm a successful save.
5. Add a direct “Choose a pass” action to empty Alarms.
6. Put the main reminder action near the pass summary, before the preview, at larger text sizes.

## Remaining verification

Device Hub computer control repeatedly times out. Inner-display rotations, book/tabletop poses, keyboard sheet layout, and continuity through open/close were not captured or verified. Inner-display layouts on the website are explicitly illustrative proposals informed by Apple guidance and the source audit.

The `inner-power-test` image is a failed diagnostic attempt: changing display power did not transfer the scene. It is excluded from the website. The `09-sky-now` image is an incomplete catalog-loading fixture and is excluded as well. No iPhone 12 or iPad image is reused as Duo evidence.

`review-plan.json` retains the full pending pose matrix. Resume with actual Device Hub controls and repeat native captures for the remaining poses. The preserved `capture-harness.patch` and `capture-duo.py` provide the temporary capture workflow; use the simulator’s current display identifier after a reboot.

## Environment

Xcode 27.1 beta is installed at `/Applications/Xcode-27.1-beta.app`. Review commands used DEVELOPER_DIR for that version without changing the system-wide selection. iOS 27.1 beta is installed. Storage cleanup was unnecessary; existing Xcode and release simulators were preserved.

## Apple references

- https://developer.apple.com/iphone-duo/
- https://developer.apple.com/documentation/technologyoverviews/preparing-your-app-for-iphone-duo
- https://developer.apple.com/videos/play/tech-talks/111461/
- https://developer.apple.com/videos/play/tech-talks/111463/
- https://developer.apple.com/documentation/xcode-release-notes/xcode-27_1-release-notes
