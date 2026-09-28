# Satellite data loading

## Ownership and concurrency

`SatelliteMetadataStore` owns the bundled read-only SQLite connection and a
2,048-entry FIFO cache of immutable `Sendable` metadata pairs. Successful reads
and missing records are cached; thrown errors and cancellation are not. The
cache is process-local and needs no TTL because the bundled database cannot
change during that process. It does not cache orbital elements, whose existing
six-hour freshness rules still apply.

The SatelliteCatalog package builds in Swift 6 language mode (tools minimum
6.2, verified with the installed Swift 6.4 compiler). SQLite connections, rows,
and query expressions stay inside the actor. The old global connection and
`@preconcurrency` suppression are gone. Query descriptors are constructed locally
instead of sharing the dependency's non-Sendable expression objects.

`SatelliteInfo.load(elements:)` awaits one metadata pair. Catalog enrichment
awaits each record separately and checks cancellation between records, allowing
station lookups to interleave with large catalogs. Only a short indexed lookup
and row decoding run during an actor turn; downloads and orbital predictions
do not run on this actor. The existing ForecastService and separate Sky Now
OrbitalService retain ownership of their work. Actor scheduling is not a strict
priority guarantee, but no request reserves the database for an entire catalog.

Onboarding preparation uses `@concurrent` and an ordinary awaited call, keeping
CPU work off the main actor while inheriting cancellation from the view task.
There is no detached task or manually forwarded cancellation for this operation.
This follows Swift's [explicit concurrent execution model](https://www.swift.org/blog/swift-6.2-released/).

## SQLite findings

The bundled database contains 51,911 SatCat rows and 4,852 UCS rows. SatCat's
`NORAD_CAT_ID` is an integer primary key; UCS has `index_norad_number` on
`NORADNumber`. Both lookup query plans already use `SEARCH`, not table scans.
No schema migration, redundant index, WAL mode, or writable database copy is
needed. Query-plan tests protect this when the catalog is regenerated.

The SatCat inclination mapping previously pointed to `PERIOD`; it now reads
`INCLINATION` (ISS: 51.64 degrees, versus its 92.93-minute period). Launch dates
use Gregorian calendar years, POSIX locale, and UTC. UCS date parsing reuses a
configured formatter rather than constructing one for every row.

## OMM parsing

OMM epoch decoding uses the Sendable value-based `Date.ISO8601FormatStyle`,
accepting fractional or whole seconds, with or without the existing UTC `Z`
suffix. This removes a new `ISO8601DateFormatter` allocation and formatter setup
for every satellite. Tests cover fractional precision, whole seconds, invalid
epochs, and six-digit NORAD IDs. TLE support and cache-validation rules remain.

## Local measurements and verification — 2026-09-28

These are development-machine microbenchmarks, not phone latency or frame-rate
claims. They exclude network downloads and orbital propagation.

| Measurement | Result |
| --- | --- |
| 100 raw dual SQLite lookups, latest SatCat IDs, median of 5 | 1.27 ms |
| 1,000 fractional epochs, per-record ISO8601DateFormatter, mean of 5 | 198.98 ms |
| Same epochs with ISO8601FormatStyle | 0.52 ms |
| 100 metadata pairs (first 100 UCS IDs), cold actor cache, Debug | 25.25 ms |
| Same metadata pairs, warm actor cache | 0.048 ms; zero additional SQL lookups |

Reproduce epoch timings with `swift scripts/benchmark-omm-dates.swift`. The
`SatelliteMetadataStoreTests.warmCatalogAvoidsDatabaseAndDecoding` test prints
cold/warm timings and asserts SQL work avoided, not fragile time thresholds.
Use `xcodebuildmcp swift-package test --package-path Frameworks/SatelliteCatalog`
to run all nine catalog tests. They also cover 64 concurrent readers, positive
and negative caching, bounded eviction, cancellation, indexes, and full row
decoding of both tables.

All 55 ForecastTests and the recorded-onboarding test passed on iPhone 17 Pro
Max / iOS 27 simulator. No production analytics events were added; cache and
benchmark diagnostics stay local. The existing operation timers continue to
include metadata lookup and decoding inside the catalog/forecast boundary.

The final app was rebuilt, launched, and visually checked in dark mode on the
iPhone 17 Pro Max simulator. The Debug device build was installed successfully
on the connected iPhone; launch was denied because the phone was locked. Phone
runtime performance has therefore not been measured for this change.
