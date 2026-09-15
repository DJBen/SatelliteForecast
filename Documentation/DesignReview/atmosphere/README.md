# Sky chart atmosphere

Native SwiftUI Canvas atmosphere shared by pass charts and Sky Now. The Sun's
azimuth and elevation come from the existing ephemeris and chart projection.

- Daylight: blue zenith and a brighter blue horizon.
- Twilight: violet/pink horizon with directional peach scattering toward the Sun.
- Visible Sun: warm aureole, soft six-blade rays and faint colored reflections
  along the Sun–chart-center axis. Optical effects fade out at the horizon;
  atmospheric twilight remains until astronomical night.
- The Moon’s disk and bloom receive the same chart-position scattering colors.
  Scattering uses a screen blend so daylight haze preserves the sunlit surface
  instead of painting over it. The opaque sky base stays behind the Moon, and
  its label stays above the effect.
- Night: the atmosphere becomes fully transparent below −18°.
- Both app appearances use the same sky colors. Paths and labels remain above
  the atmosphere; the existing star-visibility preference remains respected.

Inspired by [Earthshine](https://github.com/DJBen/earth-shine), specifically
`lib/atmosphere.ts` and `native/CAMERA-OPTICS.md`. This is an original, lightweight
chart illustration using gradients, not a port of the reference's volumetric
scattering or diffraction simulation.

## Native screenshots

`ScreenSnapshotTests.testAtmosphereScreens` finds fixed times within one day at
sun elevations −3° (dawn/dusk), +2° (sunset), +30° (daylight), and −25° (night),
then captures the real Sky Now view in light and dark appearance.
`testAtmospherePassPath` captures the native pass page for path readability.
Images live in `../after/atmosphere-*.png` alongside the existing regression
baselines. Record explicitly with the repository's `SNAPSHOT_RECORD=after`
test-plan option; ordinary test runs compare against these baselines.

`testDaytimeMoonScreens` captures a daytime Moon above 30° with the Sun above
25°, in both appearances. `testFloatingTabScreens` captures the actual tab
container with forecast, pass-list and satellite content scrolled beneath it.
