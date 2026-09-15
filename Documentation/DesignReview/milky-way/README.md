# Projected Milky Way

NASA’s [Deep Star Maps 2020](https://svs.gsfc.nasa.gov/4851/) Gaia Milky Way background replaces the procedural illustration. Credit: NASA/Goddard Space Flight Center Scientific Visualization Studio; Gaia DR2: ESA/Gaia/DPAC. This source omits the separate bright-star foreground, but still contains faint stars. It is not a model of actual observing visibility/light pollution.

The background uses the canonical Hipparcos ICRS-to-Galactic rotation, documented by [ERFA](https://github.com/liberfa/erfa/blob/master/src/icrs2g.c). Every raster pixel is inverse-projected through the chart’s azimuth/elevation mapping, then transformed using the same local mean sidereal time as SatelliteKit’s star positions. East remains left in the north-up chart. The image shares the existing sky rotation, zoom, time refresh, and horizon clipping.

The corrected 2021 Galactic EXR is downsampled in linear light to 2048 × 1024, mildly blurred, converted to sRGB, and encoded as a 257 KiB JPEG. Reproduce it with `sh scripts/prepare-milky-way.sh` (curl, ffmpeg, ImageMagick). The source checksum is pinned in that script. Longitude increases leftward, Galactic center is at the image center, north is at the top. Bilinear sampling wraps longitude and clamps latitude. Tests check decoding orientation with an asymmetric synthetic image.

Catalog stars and constellation lines draw above the background. Black source pixels become transparent while preserving the source color ratios. The source decodes once into an immutable 8 MiB RGBA cache. The output raster is bounded to 512 pixels on its longest edge (at most 1 MiB temporary RGBA), generated on the existing ChartRenderer actor, with cancellation checks per row. Light appearance uses a subtler dark tint. No runtime download or new dependency is required.

Validation: all 43 behavior/projection tests passed on iPhone 17 Pro / iOS 26.5. Tests cover Galactic center and pole registration, agreement with catalog-star projection at multiple latitudes/times, longitude seam continuity, horizon transparency, deterministic rendering, and the raster size cap. The broader run also exposed bundled satellite catalog write access causing SQLite I/O failures; opening that immutable catalog read-only restored the full suite. The full pass chart and pass-card previews were captured and visually checked on iPhone 17 Pro Max / iOS 26.5 using the existing fixed September 2026 fixtures.

Reproduce the comparison’s after images:

```sh
python3 scripts/capture-store-screenshots.py --locales en-US --screens 02-pass-chart 03-pass-list --output Documentation/DesignReview/milky-way/after
```

The procedural draft is preserved for comparison. The before images are copies of the preceding release’s matching fixtures. MapKit globe imagery can vary between runs. App Store release screenshots and TestFlight build 2 are unchanged by this feature branch.
