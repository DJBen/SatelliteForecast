# Sky Now selection review

Reviewed on iPhone 17 Pro Max / iOS 27 in dark mode at 1320 × 2868.

The selected satellite and Passing now cards share a 40-point icon column, a
24-point satellite glyph, 12-point spacing, consistent sans-serif satellite
headings, and 44-point trailing controls. Long titles wrap.

Selecting any live satellite draws a rolling ten-minute track, with five minutes
before and after the displayed time. The existing pass renderer supplies the
solid past, dotted future, illumination colors, and horizon clipping. Tracks
refresh on catalog-position updates after one minute; deselection, expiry, and
switching to a celestial object remove the selected track. Forecast-pass tracks
remain separate.

Sky Now reuses the existing planetarium offscreen arrow and recenter action.
The arrow sits between the header and cards, so it does not overlap controls.

## Verification

Six targeted PlanetariumTests passed: live interpolation/expiry, no-pass live
sky, selected track/navigation, offscreen bearing, pass track/marker agreement,
and the opt-in visual review. After enabling direct controller injection for the
visual fixture, the selected-track/navigation and visual tests passed again
(2 tests, zero failures). Build and simulator launch succeeded.

Reviewed images: `selected-dark.png`, `offscreen-dark.png`, `centered-dark.png`.
The recorded ISS fixture uses JD 2459373.9975694446 and the observer/TLEs from
`Fixture` in ScreenSnapshotTests. These are deterministic historical positions,
not current satellite observations. No station-specific branch is used for the
selected live path or arrow.

XcodeBuildMCP's AX tap helper could not load SimulatorKit with this Xcode
installation, and native Device Hub automation timed out. The visual-test host
selected the satellite and changed the camera directly. Screenshots came from
the actual simulator; the arrow's existing button wiring was reused, while
recenter behavior was exercised through the controller.

No analytics events, identifiers, or measurement boundaries were added.

## Center selection control

Added a localized scope button immediately before close on the shared selection
card. It centers the current star, body, moon, or satellite and disables device
following. Reviewed `center-control-dark.png` on the dark iPhone 17 Pro Max
simulator. Three targeted tests passed, including center-position assertions
for a star, the Moon, and a live satellite. The updated Debug build was installed
and launched successfully on the connected iPhone18,4.
