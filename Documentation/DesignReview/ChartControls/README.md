# Pass chart controls

Renamed Full screen to Chart and 3D to Planetarium in all eight supported languages.

The three buttons expand to fill the available screen width within the pass screen’s 20-point margins. The controls prefer inline icons and labels. When those do not fit, Compass becomes an icon-only button and Planetarium uses the short label “3D”; both retain their full localized accessibility names. At tighter widths, destination icons move above their labels. Compass keeps its localized accessibility label and selected state. At larger standard text sizes, equal-width buttons wrap labels. Accessibility sizes stack the three buttons vertically without reducing the requested font size. The selected compass retains its filled symbol, prominent treatment, selected accessibility trait, and On/Off value.

Dark-mode review on the iPhone 17 Pro Max simulator:
- 320-point and 375-point hosted widths, with the pass screen’s 20-point horizontal padding.
- 320 points at the largest standard and largest accessibility text sizes.
- All eight locales, with the compass enabled.
- Full pass-screen integration screenshot in screenshots/en-US/02-pass-chart.png.

The screenshot fixture is ScreenSnapshotTests.testLocalizedChartControls. No release or store screenshot upload is part of this change.
