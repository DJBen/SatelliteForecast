# Projected Milky Way

A starless procedural illustration of diffuse Galactic light, including a central bulge and dust lanes. It is not a survey image or a model of actual observing visibility/light pollution.

The background uses the canonical Hipparcos ICRS-to-Galactic rotation, documented by [ERFA](https://github.com/liberfa/erfa/blob/master/src/icrs2g.c). Every raster pixel is inverse-projected through the chart’s azimuth/elevation mapping, then transformed using the same local mean sidereal time as SatelliteKit’s star positions. East remains left in the north-up chart. The image shares the existing sky rotation, zoom, time refresh, and horizon clipping.

The diffuse image contains no point sources; catalog stars and constellation lines remain separate and draw above it. The raster is bounded to 512 pixels on its longest edge (at most 1 MiB of temporary RGBA data), generated on the existing ChartRenderer actor, with cancellation checks per row. Light appearance uses lower contrast. No texture download or new dependency is required.

Validation: all 42 behavior/projection tests passed on iPhone 17 Pro / iOS 26.5. Tests cover Galactic center and pole registration, agreement with catalog-star projection at multiple latitudes/times, longitude seam continuity, horizon transparency, deterministic rendering, and the raster size cap. The full pass chart and pass-card previews were captured and visually checked on iPhone 17 Pro Max / iOS 26.5 using the existing fixed September 2026 fixtures.

Reproduce the comparison’s after images:

```sh
python3 scripts/capture-store-screenshots.py --locales en-US --screens 02-pass-chart 03-pass-list --output Documentation/DesignReview/milky-way/after
```

The before images are copies of the preceding release’s matching fixtures. MapKit globe imagery can vary between runs. App Store release screenshots and TestFlight build 2 are unchanged by this feature branch.
