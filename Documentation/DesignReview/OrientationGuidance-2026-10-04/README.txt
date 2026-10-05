Orientation guidance restoration — October 4, 2026

Historical basis: bdcaa544 introduced the centered glass chart overlay and X close control; c59d64f5 added the persisted dismissal count and suppression preference.

Current behavior: an animated compact glass cue with three dots sits at the chart top right. Tap to expand into the chart center; X increments the existing counter and collapses back to the compact cue. After two closes, the reopened panel offers Don’t show again; selecting it persists suppression. Correct screen-down alignment also hides guidance during that pass. Fixed-chart mode is controlled by the existing Compass button beneath the chart; there is no separate guidance section.

Dark review: iPhone 17 Pro Max, full chart interaction, all eight locales at 375-point width and accessibility text size 3. The phone demonstration is decorative and omitted at accessibility sizes to keep the text and controls inside the chart. Screenshots use illustrative historical pass data, not current forecasts.

Three focused tests passed: actual close/suppression interactions and persisted preferences, localized layouts, and gravity alignment policy. English accessibility snapshots confirm both title and close button remain readable. No analytics events or screen boundaries changed.

The physical-device Debug build succeeded, installed and launched on Sihao’s iPhone. Installation and launch evidence are saved in device-install.log and device-launch.log. These changes are not part of TestFlight build 27.
