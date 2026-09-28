# 2.0.0 App Store release (September 26–27, 2026)

The replacement candidate is [build 20](build-20/README.md), with live-pass indicators,
planetarium debug time, remote Live Activities, and the Chinese name **天宫过境**.
Build 16 was withdrawn at the user’s request.

Observation home, push station reminders, Home Screen widgets with sky charts, station
video cards on the Satellites tab. Builds 12 and 13 are on internal TestFlight
([build-12](build-12/README.md), [build-13](build-13/README.md)).

## Original draft

- Created with `asc versions create --copy-metadata-from 1.8.0 --exclude-fields whatsNew
  --release-type MANUAL`: version ID `a19adf2d-b230-4638-8989-cfbabb75d7c1`,
  `PREPARE_FOR_SUBMISSION`, eight locales, five inherited screenshots each
  ([existing-inventory.json](existing-inventory.json)).
- Release notes for all eight locales are in [release-notes.json](release-notes.json) and
  were applied with `asc localizations update`.
- At draft creation, no build was attached or submitted. See the version-specific build
  evidence for later submissions.

## Screenshots (six per locale)

Captured on the iPhone 17 Pro Max simulator (iOS 27) in dark mode at 1320 × 2868. Slots
01–05 use the reviewed [screenshot moments](../ScreenshotMoments.md); their
`selection-<locale>.json` records match the 1.8.0 build 8 fixtures exactly. Slot
`06-widgets` is the Home Screen with the medium and large widgets, captured by
`scripts/capture-widget-home-screenshots.py` with the locale's language, region, time
zone and observer; its data is the live forecast at capture time.

Changes made for these captures:

- `storeScreens` renders the 2.0.0 observation home for `01-forecast` and the Satellites
  tab with station cards for `04-satellites`; the cards use an unfiltered forecast model
  so both stations show a next pass, and the tab keeps the home instant so the geography
  label matches the catalog.
- The 38 observation-home strings were added to fr, es, pt-BR, ru, ja and ko; before this
  those locales showed a mixed-language home.
- `WidgetStrings` now matches `fr_FR`-style locale identifiers; previously every widget
  outside English fell back to English text.
- `scripts/replace-store-screenshots.py` accepts trailing local slots beyond the
  inventory so the sixth image is appended.

Review: contact sheets in [visual-review](visual-review/) (aids only; the native PNGs
under `screenshots/` are what was uploaded). Upload results and post-upload verification
are in `upload-results.json` and `screenshots-verified.txt`.

## Slot order

The store order is not the capture order. en-US was rearranged by hand in App Store
Connect and the other locales were re-uploaded to match; the order is recorded in
[slot-order.json](slot-order.json): widgets, home, planetarium, pass chart, pass list,
Satellites. `replace-store-screenshots.py` uploads in filename order, so after a
reorder it reports a checksum mismatch rather than "already matches"; use the
per-locale checksum comparison in `reorder-results.json`'s workflow instead.

