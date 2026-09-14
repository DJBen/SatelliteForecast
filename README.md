# SatelliteForecast

## Installation
This project uses Swift Package Manager as its dependency management. Simply open the `.xcodeproj`

## Catalog and visual regression tests

The app uses StarryNight 3.2.0's actor-loaded, immutable sky catalog. Drawing and
hit testing read memory; star details are fetched asynchronously.

Run `python3 scripts/test-screens.py` for catalog integration and native screenshot
regressions. See [test instructions](SatelliteForecastTests/README.md) and the
[before/after design comparison](Documentation/DesignReview/index.html).
