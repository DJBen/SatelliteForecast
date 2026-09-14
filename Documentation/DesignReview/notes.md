# Design review

## Existing system

The app has light and dark system appearances, plus a global red multiply-style
night overlay. Most navigation and actions use label black/white. Eight custom
color assets cover stars, paths, constellation lines, labels and denied location.
The exact original values are preserved in `original-colors.json`.

- Lit satellite paths are black/white; unlit paths are neutral gray. These compete
  with chart borders and provide little visual hierarchy.
- Constellation strokes use 20% gray/white, making them difficult to follow.
- Pass labels invert into translucent white rectangles in dark mode.
- Physical stellar colors are applied even on white backgrounds; pale stars can
  disappear. Preserve spectral information but darken it in light mode.
- Root, forecast and category views independently override tint to black/white.
  Other screens inherit system blue. Destructive actions are red and some pass
  controls are orange. Preserve semantic warning/destructive distinctions.
- Forecast cards have 225-point video headers and no inter-card spacing. Navigation
  headings are hidden; category cards and forecast cards use different treatments.
- Settings use several unrelated system gray surfaces and small-cap headers.
- Onboarding uses a black video background but system secondary-label text; in
  light appearance this produces dark copy over dark footage.
- Night mode is an overlay, not an independent palette. The comparison needs to
  show whether it preserves useful text and chart contrast after the restyle.

## Direction

Use quiet cool surfaces, clear card boundaries and consistent teal interactive
accents. Keep amber for upcoming visible passes and red for destructive actions.
Unify card spacing, radius and content padding; make chart paths more distinct
than constellation strokes. Keep the astronomy content and familiar navigation.

Screenshots use the actual native views with fixed date, location and orbital
fixtures, in light and dark appearances. Video is frozen at a known frame for
repeatability. The catalog is real StarryNight data. No notification scheduling,
location authorization or live ephemeris download runs in the snapshot host.

## Implemented

- Introduced `AppTheme` for surfaces, accent, muted text, borders and warnings.
- Unified forecast and category cards with 20-point corners, inset layouts and
  visible headings. Reduced forecast video height to make room for pass details.
- Fixed forecast countdowns that requested white text on a white card.
- Replaced Settings' green, blue and purple gradients with consistent cards.
- Fixed onboarding descriptions to remain legible over dark video in both themes.
- Updated all eight chart/status color assets; adjusted spectral star colors for
  light backgrounds without changing the stellar class mapping.
- Made sky and satellite-path cache keys appearance-aware and request fresh
  rendering when the system appearance changes. Rasterization now resolves
  stellar colors under the requested trait collection.
- Retained red night mode and checked its screenshots in both appearances.

## Additional issue found by screenshots

Mission Control mixed an injected historical date with the wall clock when
building a ground-track range. The first screenshot run produced years of map
points and exceeded 9 GB of memory. Both endpoints now derive from the injected
date. The same historical fixture subsequently completed normally.

## Scope of visual coverage

The suite covers onboarding (both pages), forecast overview, categories,
satellite list, pass forecast with map, pass detail, enlarged sky, Sky Now,
settings, location, alarms, pass alarm configuration, ephemerides, selected star,
night mode, Mission Control, raw ephemeris text, pass tutorial and debug menu.
Captures show the initial viewport. System-owned share sheets, permission alerts,
keyboard variants and every scrolled position are outside this baseline set.
MapKit tile imagery is external and may vary independently of this app.
