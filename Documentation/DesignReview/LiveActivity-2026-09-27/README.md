# Live Activity locale review — September 27, 2026

Native SwiftUI content rendered on iPhone 17 Pro Max / iOS 27 simulator in dark
mode. The eight contact sheets each show both stations and all three illumination
scenarios, including enlarged-text stale and finished layouts. These shared-view
renders verify localized content; they are not screenshots of the system's Lock
Screen or Dynamic Island chrome. Compact/minimal layouts use station artwork and
system countdowns, without translated visible labels.

- [English](en.png)
- [Spanish](es.png)
- [French](fr.png)
- [Brazilian Portuguese](pt-BR.png)
- [Russian](ru.png)
- [Simplified Chinese](zh-Hans.png)
- [Japanese](ja.png)
- [Korean](ko.png)

All 864 renders passed the 160-point height assertion: 8 languages × 2 stations ×
3 illumination scenarios × 6 states × 3 size/text profiles. Contact sheets were
visually reviewed for clipping, legibility, arc continuity and localized labels.
The initial large-text overflow and segmented-line seams were fixed before this
passing run. At larger text sizes, artwork yields its space to text and status
moves below the arc; the diagram and legend retain compact readable type.

[11 tests passed](tests.log), with no skips: lifecycle, states/resources, locale
matrix, and eight native architecture regressions. The lifecycle test verifies an
immediate ActivityKit request, cancellation, and a scheduled activity progressing
from pending to active. Cancellation assertions wait for asynchronous state
propagation rather than assuming immediate observation after `end` returns.

`python3 scripts/audit-live-activity-localizations.py` passes: 22 new keys per
language, full WidgetSupport key parity, no duplicate keys and matching format
arguments. Accessibility elevation strings use degree symbols to avoid incorrect
singular/plural grammar. Translations are not independently native-speaker reviewed.

The broader pre-existing localization audit reports the existing literal `FPS`
in PlanetariumView, unrelated to this feature. New Live Activity strings are
covered by the dedicated audit and compiled-resource tests.

Run `python3 scripts/capture-live-activity-review.py --simulator <UDID> --output <new-dir>`
to regenerate the full matrix. A unique output directory is required. No light-mode
captures were made. See the implementation document for the APNs/background
lifecycle boundary; exact background phase delivery/end is not claimed here.

A subsequent [integration run](integration-tests.log) passed all 10 selected
state/resource, ActivityKit lifecycle, and architecture tests after updating
accessibility degree formatting. No snapshot layout changed.
