# Native screen snapshots

Run `python3 scripts/test-screens.py` from the repository root. The shared Xcode
scheme includes the integration and screenshot target; no missing test plan is
required. Default execution compares images and never records baselines.

To intentionally regenerate reviewed baselines, run:

```
python3 scripts/test-screens.py --record after
```

Use `--record before` only when starting a new design comparison. The runner
restores the checked-in test plan after the run and fails if the MCP tool reports
a test failure even when its process exit status is zero.

Snapshots are 402 × 874 points at 1×, English, UTC, standard Dynamic Type. Run on
the pinned iPhone 17 Pro / iOS 26.5 simulator for pixel comparisons. Images and
XCTest attachments cover actual app views, not HTML recreations. Record on the
same simulator/runtime used for verification. The snapshot fixture uses fixed
2021 orbital elements near their epoch, a fixed observer, the real bundled star
catalog, frozen video frames and only local chart rendering middleware. It does
not run production network, notification or location middleware.

The comparison metric is mean absolute RGBA pixel error with a 0.4% tolerance
for antialiasing. Missing baselines fail. Review the attached actual screenshot
and the before/after artifact before accepting changes. The suite is a visual
regression check, not a substitute for navigation, VoiceOver or device testing.

The runner disables automatic SwiftPM updates and uses the committed resolutions.
All 40 comparisons passed in a comparison-only run on the reference runtime.
MapKit regions are not masked; external tile updates can require a reviewed
baseline refresh. Scene-owned sensor dependencies are supplied, but simulator
snapshots do not validate physical compass accuracy.

## Moonstone dark baselines

The September 27, 2026 dark baselines were reviewed on iPhone 17 Pro Max / iOS 27.
Light baselines retain their earlier reference runtime. For a palette review,
use `scripts/capture-moonstone-review.py --output /absolute/new/evidence` and
repeat with `--extended` for secondary fixtures. These commands record isolated
evidence; they do not automatically accept baselines. `SNAPSHOT_DARK_ONLY=1`
skips light captures, `SNAPSHOT_OUTPUT` redirects output, and
`SNAPSHOT_PLANETARIUM=1` opts into the live Metal fixture. See
[Moonstone verification](../Documentation/DesignReview/Moonstone.md) for
coverage and known limitations. The latest runs were recording runs; no new
comparison-only pass is claimed.
