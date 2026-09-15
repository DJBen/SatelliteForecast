# Phased, oriented Moon

The same renderer supplies the interactive sky chart and rasterized notification
charts. The existing generic Moon symbol and yellow halo are removed.

- Phase comes from the Moon-to-Sun and Moon-to-observer vectors, with observer
  parallax. Lunar position uses SatelliteKit's NASA/Simpson `lunarCel` model;
  the Sun uses the app's VSOP87 ephemeris. These remain approximate ephemerides.
- Lighting axes follow the local orientation of the azimuthal sky chart, rather
  than assuming a fixed waxing-right/waning-left icon. Whole-chart rotation
  naturally rotates the Moon with the sky.
- NASA/JPL NAIF's IAU_MOON pole and prime-meridian periodic terms orient the
  texture, including libration. Source: https://naif.jpl.nasa.gov/pub/naif/generic_kernels/pck/pck00011.tpc
- The NASA SVS color map is bundled at 512 × 256 (38 KB). A small spherical
  raster provides the curved terminator and visible maria. No relief mesh or
  terrain shadows are needed at this size.
- Earthshine varies with the illuminated Earth fraction and fades in daylight.
  Its brightness is lifted for chart legibility, not calibrated photometry.
  There is no eclipse shadow simulation. In daytime, the unlit portion lets
  the foreground atmosphere show through.
- Photographic rendering raises the lit surface's exposure and adds three soft
  scattering widths from a separate sunlit-only image. Cool neutral bloom fades
  in daylight. A padded 288 × 288 image holds the glow around the unchanged
  96-pixel lunar disk, so the actual Moon stays the same size in the chart.
- An actor renders images off the UI thread and retains at most 64 small images.

## Validation

`MoonAppearanceTests` checks four published 2024 phase instants, chart-axis
orientation across northern/southern and polar observers, lunar near-side
registration, image bounds, deterministic rasterization, and Earthshine/daylight
behavior. Phase reference: https://www.astropixels.com/almanac/almanac21/almanac2024gmt.html

`ScreenSnapshotTests.testMoonPhaseScreens` captures a four-phase review sheet
(enlarged and actual-size icons) plus the actual Sky Now chart in both themes.
Screenshots: `../after/moon-phases-dark.png`, `../after/moon-chart-dark.png`,
`../after/moon-chart-light.png`. Existing atmosphere captures are refreshed
because visible Moons now have a different shape and texture.

Texture / imagery credit: NASA's Scientific Visualization Studio.
https://svs.gsfc.nasa.gov/4720/
