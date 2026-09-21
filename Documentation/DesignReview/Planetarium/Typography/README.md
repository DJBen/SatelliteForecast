# New York sky labels and bright-star names

Reviewed in dark mode on iPhone 17 Pro Max (iOS 26.5).

- Native captures: `screenshots/en-US/02-pass-chart.png` and `05-planetarium.png`.
- Offscreen Metal zoom check: `zoomed-star-names-dark.png` (rendering diagnostic, not a store screenshot).
- Celestial labels and selection names use Apple’s system serif; controls and numerical readouts remain unchanged.
- Cached top-50 catalog names are prioritized by magnitude after viewport/visibility filtering. Proper names fall back to existing Bayer/catalog designations where necessary.
- 3D limits: 3 names at wide FOV, 5 at medium FOV, 7 at close FOV. Names avoid other labels and viewport edges, respect Labels off, and disappear in daytime.
- 2D limits: 3 names on ordinary charts, 6 on larger charts. Collision space is reserved only for constellation labels actually displayed, plus planetary annotations.
- Final behavior suite: 99 passed, 0 failed, 2 opt-in review tests skipped. New checks cover the 50-star subset, magnitude ranking, nonempty cached names, viewport star-label visibility, zoom budgets, Labels off, and daytime hiding.
- App rebuilt and rerun after implementation changes. No App Store/TestFlight assets or builds updated for this typography change.
