# Moonstone appearance

Moonstone uses neutral charcoal, soft white and a desaturated silver-blue accent.
Real atmospheric blues, violets and pinks remain independent of the interface palette. The committed arc trim is
unchanged.

| Role | Dark value |
| --- | --- |
| Page | `#111214` |
| Card | `#1C1E22` |
| Primary text | `#ECEEF2` |
| Secondary text | `#A3A8B2` |
| Actions / illuminated trajectory | `#A9B9CE` |
| Separators | `#33363D` |
| Semantic warning | `#F0A184` |

`MoonstonePalette.swift` supplies app, widget and Metal interface colors.
Static-chart and system accent assets mirror the dark tokens. Featured cards
use a 10% accent radial tint near their lower edge; widget backgrounds use 8%.
Page backgrounds have no colored glow. The static grain remains subtle and
Increase Contrast / Reduce Transparency suppress both texture and tint.

Light appearance is outside this review. Photos, maps, atmospheric rendering,
planetary artwork and the red night-vision overlay retain their physical or
functional colors. Analytics semantics are unchanged.

## Evidence

Native captures use iPhone 17 Pro Max / iOS 27 in dark mode, through
`scripts/capture-moonstone-review.py --output /absolute/new/evidence`.

- [Reviewed app snapshots](after/)
- [Selected screens](Moonstone/app-overview.jpg)
- [Widgets](Moonstone/widgets.png)

## Verification — September 27, 2026

Built and reran the app and widget extension on iPhone 17 Pro Max / iOS 27.
Five primary and nine secondary native capture tests completed with zero failures.
These were recording runs, not a comparison-only run. Reviewed the 49 distinct
app captures across main screens, home states, scrolling, tutorials, localization,
and atmospheric conditions, plus native previews of all three widget sizes.
The 49 reviewed dark app images replace their prior palette baselines.

The optional live Metal planetarium capture was not rerun; its interface colors
use the same shared tokens and its code compiled successfully. The earlier
planetarium image is historical evidence, not a Moonstone capture. Installed
widget refresh timing and light mode were not checked. Existing large-text
crowding around the home time/alarm control remains outside this palette change.

- [Primary passing tests](Moonstone/primary-tests.log)
- [Secondary passing tests](Moonstone/secondary-tests.log)

## Device installation

The Debug app and widget extension built successfully for physical iOS hardware.
The app was installed and launched successfully on the user's wired iPhone
running iOS 27. This confirms installation and process launch; the screenshots
above are simulator/native-preview evidence, not physical-device captures.
A separate fresh widget preview capture also passed after the palette review.

- [Fresh widget capture test](Moonstone/widget-tests.log)
