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
