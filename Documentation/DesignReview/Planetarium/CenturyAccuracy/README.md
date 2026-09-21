# Planetarium century-range validation

Validated interval: **1926-09-20 through 2126-09-20**, monthly (2,401 epochs ×
seven planets = 16,807 comparisons). JPL Horizons references fetched 2026-09-20.
Tests read these pinned references offline. Refresh with
`python3 scripts/fetch-planet-century-reference.py` from the repository root.

Maximum measured absolute differences against Horizons:

| Planet | Ring/pole opening ° | Pole position angle ° | Illuminated fraction (percentage points) | Astrometric position ° |
|---|---:|---:|---:|---:|
| Mercury | 0.000632 | 0.005400 | 0.008936 | 0.002169 |
| Venus | 0.001008 | 0.004815 | 0.006292 | 0.001850 |
| Mars | 0.001170 | 0.006179 | 0.003386 | 0.001728 |
| Jupiter | 0.002000 | 0.006272 | 0.000481 | 0.000471 |
| Saturn | 0.000122 | 0.003231 | 0.000196 | 0.000283 |
| Uranus | 0.000425 | 0.046672 | 0.000075 | 0.000448 |
| Neptune | 0.000297 | 0.007260 | 0.000040 | 0.000729 |

These are sampled comparisons, not mathematical bounds over every instant.
The analytic VSOP87A series is evaluated at the requested epoch, with iterated
light time; this is not a repeated modern-date cycle or linear orbit extrapolation.
IAU pole orientation is evaluated at emission time. IAU 2006 precession now maps
J2000 vectors into the observer's equator-of-date correctly. The old frozen-frame
comparison reached 0.734° of Saturn pole-angle error over this interval.

The app uses mean-of-date precession, without the full nutation/aberration model
used by Horizons apparent pole angles. Uranus has a less stable position-angle
comparison near a pole-on view, where the projected axis is short. Earth rotation,
refraction and local observing conditions are outside these geocentric comparisons.
Planet texture longitude and procedural ring photometry are still illustrative.
This establishes a tested 200-year interval, not an unlimited accuracy claim.

Sources: [JPL Horizons](https://ssd.jpl.nasa.gov/horizons/manual.html),
[VSOP87 implementation and truncation](https://github.com/gmiller123456/vsop87-multilang),
[IAU SOFA precession standards](https://www.iausofa.org/current-software).
The `*-header.txt` files record the reference ephemeris, target radii, and options;
`monthly-reference.json` columns are documented in the fetch script.
`measured-errors.json` records worst-case values and their Julian dates.

Dark iPhone 17 Pro Max app screenshots were reviewed at JD 2424779.4839938385
(1926) and JD 2497828.3075299426 (2126). The interactive fixture overrides the
rendered date independently of its 2021 pass-control clock, so the on-screen
pass date is not the rendered planet epoch. Both use observer 37.49°, −122.23°.
