# SatelliteForecast

## Installation
This project uses Swift Package Manager as its dependency management. Simply open the `.xcodeproj`

## Backend

The [pass-prediction](pass-prediction/README.md) folder contains the satellite
prediction API, Firebase push notification service, scheduled jobs, and orbital
data cache. Previously maintained in a separate repository, the backend now lives
alongside the app here.

Run backend commands from `pass-prediction/`. Its Firebase and Google Cloud project
is `pass-prediction`; see the [backend README](pass-prediction/README.md) for setup
and testing instructions.

## Catalog and visual regression tests

The app uses StarryNight 3.2.0's actor-loaded, immutable sky catalog. Drawing and
hit testing read memory; star details are fetched asynchronously.

Run `python3 scripts/test-screens.py` for catalog integration and native screenshot
regressions. See [test instructions](SatelliteForecastTests/README.md) and the
[before/after design comparison](Documentation/DesignReview/index.html).
