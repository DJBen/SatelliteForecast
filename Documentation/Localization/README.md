# Localization coverage review — September 17, 2026

The app supports English, French, Spanish, Brazilian Portuguese, Russian, Simplified Chinese, Japanese, and Korean.

This review added 49 interface keys in every language, including the phone-orientation title and instructions, accessibility guidance, loading and location-search feedback, alarm errors, timed-pass link errors, planetarium controls and object details, and compact compass/station labels. The system motion permission description is also translated. Longer guidance titles can wrap vertically.

Existing alarm copy, settings/category labels, and orbital-data errors were looking in the main app bundle while their translations live in Swift package resource bundles. These lookups now use the correct package bundle. Buttons and other controls with implicit main-bundle lookups now resolve explicitly. English tables now contain explicit fallback values for all interface keys, including the existing multiline descriptions.

## Verification

- `python3 scripts/audit-localizations.py`: 269 implementation strings and 2 public error strings per language; key parity, duplicate keys, format argument types/counts, plural key coverage and required `other` forms, InfoPlist language coverage, and basic source-key checks passed.
- `LocalizationTests/testCompiledResourcesContainGuidanceAndFormatsInEveryLanguage`: simulator test passed; verifies real compiled bundle lookup and formatted error substitution for each language.
- `ScreenSnapshotTests/testLocalizedOrientationGuidance`: simulator test passed; generates the eight adjacent `guidance-*-dark.png` images at a 375-point phone width, including the optional dismissal button. All eight images were visually reviewed; titles, instructions, and buttons fit.
- Simulator app rebuilt and relaunched in dark mode after the changes.

## Scope and maintenance

This was a source/resource coverage audit and a visual review of the guidance card, not an exhaustive linguistic review or a screenshot sweep of every screen in every language. Translations were authored during the implementation and have not been independently reviewed by native speakers.

Official catalog names (including star names, constellation names and satellite catalog designations), NORAD/HIP identifiers, astronomical symbols and standard unit notation are kept as data. Apple-provided error descriptions use the system's localization. Developer-only debug labels and the unused `SkyChartPopover` placeholder are excluded from production copy coverage. The audit's source scan catches simple literal calls; dynamically composed content still needs manual review.

For new SwiftUI `Text` in the implementation package, pass `bundle: .module`. For runtime messages, UIKit labels, host-app controls, or formatted strings, use `AppLocalization` so lookup targets the implementation bundle. Keep translations and formatting placeholders consistent in all eight tables, and run the audit before shipping new copy. Plural messages belong in `Localizable.stringsdict`.
