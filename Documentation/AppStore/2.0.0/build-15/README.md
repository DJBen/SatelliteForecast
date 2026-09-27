# 2.0.0 builds 14 and 15 — redesigned two-row widgets (September 27, 2026)

Small widget: the sooner pass leads with the station icon, an elevation chip, a large
rounded time and a "day · duration" line; the other station sits in a compact footer.
Medium widget: one row per station with icon, route and duration, a right-aligned time
with its day, and the peak elevation on the arc. Widgets are localized in all eight
languages (day words, minutes, station names) and the extension declares its
localizations. Mockups and rationale:
`Documentation/DesignReview/WidgetTwoRow-2026-09-27-mockups.html`.

## Builds

- **14** (`e96b804b-5b1a-4728-a894-e0a0e102c283`): uploaded before the taller medium rows
  and the compact footer fix; VALID, IN_BETA_TESTING. Superseded.
- **15** (`a0ca6293-aed6-462a-9d9c-8d16cf49f3f5`): final layout. VALID, uploaded
  2026-09-27 00:53 PDT, IN_BETA_TESTING on First Light, external
  READY_FOR_BETA_SUBMISSION, not submitted. Publish log in
  [publish-log.txt](publish-log.txt); notes in [test-notes-en-US.txt](test-notes-en-US.txt).
  Build 15 still shows "Сегодня вечером" in the Russian medium widget, which can clip the
  route on the widest day; the strings now say "Вечером" for the next build.

## Verification

- Widget locale matrix (`Documentation/WidgetPreviews/2026-09-27-two-row/`): 48 renders
  across eight locales, normal/XXXL/AX5 text, 146 and 170 pt small widths, in-progress,
  empty, expired and setup states; all inside bounds.
- `scripts/test-screens.py --behavior-only --simulator 0D39CA43-…`: 129 passed, 0 failed,
  2 skipped, run after the final layout.

## App Store draft

The `06-widgets` slot was recaptured in all eight locales with the final medium layout
and re-uploaded with `scripts/reorder-store-screenshots.py` in the store order
(widgets, home, planetarium, pass chart, pass list, Satellites); the other five slots
are unchanged. Post-upload verification: `screenshots-verified.txt` in the release root.
No build attached, no review submission.
