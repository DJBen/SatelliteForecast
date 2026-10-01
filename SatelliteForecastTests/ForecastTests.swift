import XCTest
import UIKit
import SwiftUI
import BTree
import QSMag
import SatelliteForecast
import SatelliteKit
import SatelliteWidgetSupport
@testable import SatelliteForecastImpl


@MainActor
func weatherTestForecast(at date: Date, condition: String? = "PartlyCloudy", daylight: Bool = false,
                         stale: Bool = false, status: String = "ok", temperature: Double? = 16) throws -> HomeWeatherForecast {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    let hour = Date(timeIntervalSince1970: floor(date.timeIntervalSince1970 / 3600) * 3600)
    let value: [String: Any] = [
        "schemaVersion": 1,
        "providers": ["weatherkit": ["status": status, "stale": stale, "fetchedAt": formatter.string(from: date)]],
        "hours": [["time": formatter.string(from: hour), "weather": ["temperatureC": temperature as Any? ?? NSNull(),
            "conditionCode": condition as Any? ?? NSNull(), "daylight": daylight]]],
        "attribution": ["weatherkit": ["legalPageURL": "https://weatherkit.apple.com/legal-attribution.html"]]
    ]
    return try HomeWeatherForecast.decode(JSONSerialization.data(withJSONObject: value))
}

@MainActor
final class HomeWeatherTests: XCTestCase {
    private let date = Date(timeIntervalSince1970: 1_800_000_000)
    private let sf = HomeWeatherLocation(CLLocationCoordinate2D(latitude: 37.77, longitude: -122.42))!
    private let la = HomeWeatherLocation(CLLocationCoordinate2D(latitude: 34.05, longitude: -118.24))!

    func testFreshnessAndMissingWeather() throws {
        let forecast = try weatherTestForecast(at: date)
        XCTAssertNotNil(forecast.current(at: date))
        XCTAssertNil(forecast.current(at: date.addingTimeInterval(900)))
        XCTAssertNil(forecast.current(at: date.addingTimeInterval(-121)))
        XCTAssertNil(try weatherTestForecast(at: date, stale: true).current(at: date))
        XCTAssertNil(try weatherTestForecast(at: date, status: "unavailable").current(at: date))
        XCTAssertNil(try weatherTestForecast(at: date, temperature: nil).current(at: date))
        XCTAssertNotNil(try weatherTestForecast(at: date, status: "partial").current(at: date))
        let boundary = Date(timeIntervalSince1970: floor(date.timeIntervalSince1970 / 3600) * 3600 + 3599)
        XCTAssertNil(try weatherTestForecast(at: boundary).current(at: boundary.addingTimeInterval(1)))
    }

    func testLocalizedTemperatureAndDayNightIcons() throws {
        let night = try XCTUnwrap(weatherTestForecast(at: date, condition: "Clear", temperature: 0).current(at: date))
        XCTAssertTrue(night.temperature(locale: Locale(identifier: "en_US")).contains("32"))
        XCTAssertTrue(night.temperature(locale: Locale(identifier: "fr_FR")).contains("0"))
        XCTAssertEqual(night.condition.symbol, "moon.stars.fill")
        let day = try XCTUnwrap(weatherTestForecast(at: date, condition: "Clear", daylight: true).current(at: date))
        XCTAssertEqual(day.condition.symbol, "sun.max.fill")
        let unknown = try XCTUnwrap(weatherTestForecast(at: date, condition: "FutureCondition").current(at: date))
        XCTAssertEqual(unknown.condition.title, "Weather")
    }

    func testLocationRoundingAndUnsupportedCoordinates() {
        XCTAssertEqual(sf, HomeWeatherLocation(CLLocationCoordinate2D(latitude: 37.7701, longitude: -122.4201)))
        XCTAssertNil(HomeWeatherLocation(CLLocationCoordinate2D(latitude: 90, longitude: 0)))
        XCTAssertNil(HomeWeatherLocation(CLLocationCoordinate2D(latitude: .nan, longitude: 0)))
    }

    func testCacheExpiresAndLocationSwitchClearsReading() async throws {
        var clock = date
        var calls = 0
        let model = HomeWeatherModel(load: { _ in calls += 1; return try weatherTestForecast(at: clock) }, now: { clock })
        await model.refresh(sf)
        await model.refresh(sf)
        XCTAssertEqual(calls, 1)
        XCTAssertNotNil(model.current(for: sf))
        XCTAssertNil(model.current(for: la))
        clock = clock.addingTimeInterval(901)
        await model.refresh(sf)
        XCTAssertEqual(calls, 2)
        await model.refresh(la)
        XCTAssertNil(model.current(for: sf))
        XCTAssertNotNil(model.current(for: la))
        await model.refresh(nil)
        XCTAssertNil(model.current(for: la))
    }

    func testSupersededLocationCannotPublishOrStopLoading() async throws {
        var pending: [HomeWeatherLocation: CheckedContinuation<HomeWeatherForecast, Error>] = [:]
        let model = HomeWeatherModel(load: { coordinate in
            try await withCheckedThrowingContinuation { pending[coordinate] = $0 }
        }, now: { self.date })
        let first = Task { await model.refresh(sf) }
        while pending[sf] == nil { await Task.yield() }
        let second = Task { await model.refresh(la) }
        while pending[la] == nil { await Task.yield() }
        XCTAssertNil(model.current(for: sf))
        pending[sf]?.resume(returning: try weatherTestForecast(at: date))
        await first.value
        XCTAssertTrue(model.isLoading)
        XCTAssertNil(model.current(for: la))
        pending[la]?.resume(returning: try weatherTestForecast(at: date, condition: "Rain"))
        await second.value
        XCTAssertEqual(model.current(for: la)?.condition.title, "Rain")
        XCTAssertFalse(model.isLoading)
    }

    func testFailuresBackOffAndCancellationAllowsImmediateRetry() async throws {
        var calls = 0
        let failing = HomeWeatherModel(load: { _ in calls += 1; throw URLError(.notConnectedToInternet) }, now: { self.date })
        await failing.refresh(sf)
        await failing.refresh(sf)
        XCTAssertEqual(calls, 1)
        XCTAssertTrue(failing.failed)
        await failing.refresh(sf, force: true)
        XCTAssertEqual(calls, 2)
        var cancelled = true
        let model = HomeWeatherModel(load: { _ in
            if cancelled { cancelled = false; throw URLError(.cancelled) }
            return try weatherTestForecast(at: self.date)
        }, now: { self.date })
        await model.refresh(sf)
        XCTAssertFalse(model.failed)
        await model.refresh(sf)
        XCTAssertNotNil(model.current(for: sf))
    }
}

@MainActor
final class ForecastTests: XCTestCase {
    private let date = Date(timeIntervalSince1970: 1_622_592_000)
    private let observer = LatLonAlt(37, -122, 0)

    func testWidgetPassTransitionsAndExpiry() {
        let first = WidgetPass(station: 25544, rise: date.addingTimeInterval(60),
            peak: date.addingTimeInterval(120), set: date.addingTimeInterval(180),
            elevation: 60, startDirection: "W", endDirection: "E")
        let second = WidgetPass(station: 25544, rise: date.addingTimeInterval(300),
            peak: date.addingTimeInterval(360), set: date.addingTimeInterval(420),
            elevation: 40, startDirection: "NW", endDirection: "SE")
        let expiry = date.addingTimeInterval(600)
        let forecast = WidgetForecast(generated: date, expires: expiry, passes: [second, first])
        XCTAssertEqual(forecast.next(station: 25544, at: date), first)
        XCTAssertEqual(forecast.next(station: 25544, at: first.rise), first)
        XCTAssertEqual(forecast.next(station: 25544, at: first.set), second)
        XCTAssertNil(forecast.next(station: 48274, at: date))
        XCTAssertNil(forecast.next(station: 25544, at: date.addingTimeInterval(-1)))
        XCTAssertNil(forecast.next(station: 25544, at: expiry))
        XCTAssertEqual(forecast.entryDates(after: date), [date, first.rise, first.set, second.rise, second.set, expiry])
        XCTAssertEqual(forecast.entryDates(after: expiry), [expiry])
    }

    func testWidgetForecastStoreCachesRecentPlaces() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let original = WidgetForecastStore.directory
        WidgetForecastStore.directory = directory
        defer {
            WidgetForecastStore.directory = original
            try? FileManager.default.removeItem(at: directory)
        }
        let expires = date.addingTimeInterval(7 * 86_400)
        func forecast(_ latitude: Double, _ longitude: Double) -> WidgetForecast {
            .init(generated: date, expires: expires, passes: [], latitude: latitude, longitude: longitude)
        }
        // San Francisco, San Jose, Sacramento, Los Angeles, Seattle: each more than 25 km apart.
        let places = [(37.77, -122.42), (37.34, -121.89), (38.58, -121.49), (34.05, -118.24), (47.61, -122.33)]
        for (latitude, longitude) in places.prefix(3) {
            WidgetForecastStore.write(forecast(latitude, longitude), now: date)
        }
        XCTAssertEqual(WidgetForecastStore.read()?.latitude, 38.58)

        // A few kilometres of GPS drift keeps the current forecast.
        WidgetForecastStore.activate(latitude: 38.60, longitude: -121.50, now: date)
        XCTAssertEqual(WidgetForecastStore.read()?.latitude, 38.58)

        // Returning to an earlier place shows its cached forecast without recomputing.
        WidgetForecastStore.activate(latitude: 37.77, longitude: -122.42, now: date)
        XCTAssertEqual(WidgetForecastStore.read()?.latitude, 37.77)

        // A place with no cached forecast shows setup.
        WidgetForecastStore.activate(latitude: 40.71, longitude: -74.01, now: date)
        XCTAssertNil(WidgetForecastStore.read())

        // Four places stay cached; the least recently used one (San Jose) is evicted.
        for (latitude, longitude) in places.suffix(2) {
            WidgetForecastStore.write(forecast(latitude, longitude), now: date)
        }
        for (latitude, longitude) in [places[0], places[2], places[3]] {
            WidgetForecastStore.activate(latitude: latitude, longitude: longitude, now: date)
            XCTAssertEqual(WidgetForecastStore.read()?.latitude, latitude)
        }
        WidgetForecastStore.activate(latitude: 37.34, longitude: -121.89, now: date)
        XCTAssertNil(WidgetForecastStore.read())

        // Expired forecasts are not reused for a different place.
        WidgetForecastStore.activate(latitude: 37.77, longitude: -122.42, now: expires)
        XCTAssertNil(WidgetForecastStore.read())
        let json = try FileManager.default.contentsOfDirectory(atPath: directory.path).filter { $0.hasSuffix(".json") }
        XCTAssertEqual(json.count, 5, "four place forecasts plus the index")
    }

    func testWidgetForecastRoundTrip() throws {
        let forecast = WidgetForecast.preview(at: date)
        let decoded = try JSONDecoder().decode(WidgetForecast.self, from: JSONEncoder().encode(forecast))
        XCTAssertEqual(decoded.passes, forecast.passes)
        XCTAssertEqual(decoded.expires, forecast.expires)
    }

    func testWidgetSkyProjectionMatchesApp() {
        for azimuth in stride(from: 0.0, through: 360.0, by: 15) {
            for elevation in [0.0, 30, 60, 90] {
                let unit = WidgetSkyPoint(azimuth: azimuth, elevation: elevation).unitPoint
                let app = SkyChartUtils.point(at: .init(azimuth, elevation), rect: .init(x: 0, y: 0, width: 200, height: 200))
                XCTAssertEqual(100 + unit.x * 100, app.x, accuracy: 0.00001)
                XCTAssertEqual(100 + unit.y * 100, app.y, accuracy: 0.00001)
                XCTAssertLessThanOrEqual(hypot(unit.x, unit.y), 1.00001)
            }
        }
    }

    func testLargeWidgetSelectsEarliestStationAndReadsLegacyCache() throws {
        let original = WidgetForecast.preview(at: date)
        XCTAssertEqual(original.next(at: date)?.station, 25544)
        XCTAssertEqual(original.next(at: original.passes[0].set)?.station, 48274)
        XCTAssertNil(original.next(at: original.expires))
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(original)) as? [String: Any])
        var passes = try XCTUnwrap(json["passes"] as? [[String: Any]])
        for index in passes.indices { passes[index].removeValue(forKey: "skyTrack") }
        json["passes"] = passes
        let legacy = try JSONDecoder().decode(WidgetForecast.self, from: JSONSerialization.data(withJSONObject: json))
        XCTAssertNil(legacy.next(at: date)?.skyTrack)
        XCTAssertEqual(legacy.next(at: date)?.station, 25544)
    }

    func testWidgetTracksUsePropagatedPositions() async throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let service = ForecastService(cacheDirectory: folder, fetch: { _ in tle })
        let request = ForecastRequest(observer: observer, dateRange: date.julianDate...(date.julianDate + 2))
        let found = try await service.passes(for: .iss, request: request)
        let pass = try XCTUnwrap(found.first)
        let tracks = try await service.widgetTracks(for: .iss, request: request, passes: [pass])
        let points = try XCTUnwrap(tracks[pass.rise.julianDate])
        XCTAssertGreaterThan(points.count, 2)
        XCTAssertLessThanOrEqual(points.count, 121)
        XCTAssertEqual(points.first!.azimuth, pass.rise.azim, accuracy: 0.2)
        XCTAssertEqual(points.last!.azimuth, pass.set.azim, accuracy: 0.2)
        let info = try await service.satelliteInfo(for: .iss)
        for index in points.indices {
            let jd = pass.rise.julianDate + (pass.set.julianDate - pass.rise.julianDate) * Double(index) / Double(points.count - 1)
            let expected = try SatelliteSnapshot(satelliteInfo: info, julianDate: jd, observer: observer)
            XCTAssertEqual(points[index].elevation, expected.position.elev, accuracy: 0.00001)
            XCTAssertEqual(points[index].illuminated, pass.isIlluminated(at: jd))
        }
    }

    func testWidgetSkyUsesOnlyBrightAboveHorizonCatalogStars() async throws {
        let catalog = try await AppStarCatalog.load()
        let service = ForecastService(brightStars: catalog.stars(maximumMagnitude: 6.5))
        let pass = pass(at: date)
        let request = ForecastRequest(observer: observer, dateRange: date.julianDate...(date.julianDate + 1))
        let skies = try await service.widgetSkies(request: request, passes: [pass])
        let sky = try XCTUnwrap(skies[pass.rise.julianDate])
        let image = try XCTUnwrap(sky.imagePNG.flatMap { UIImage(data: $0) })
        XCTAssertEqual(image.size.width * image.scale, 560)
        XCTAssertEqual(image.size.height * image.scale, 560)
        XCTAssertFalse(sky.stars.isEmpty)
        XCTAssertLessThanOrEqual(sky.stars.count, 80)
        XCTAssertTrue(sky.stars.allSatisfy { $0.magnitude <= 3 && $0.position.elevation > 0 })
        let expected = catalog.stars(maximumMagnitude: 3).sorted { $0.magnitude < $1.magnitude }.compactMap { star -> WidgetStar? in
            let point = azel(time: Date(julianDate: pass.culmination.julianDate), site: LatLon(observer), cele: RADec(star.coordinate))
            guard point.elev > 0 else { return nil }
            return WidgetStar(position: .init(azimuth: point.azim, elevation: point.elev), magnitude: star.magnitude, spectralClass: star.spectralClass)
        }
        XCTAssertEqual(sky.stars, Array(expected.prefix(80)))
        let decoded = try JSONDecoder().decode(WidgetSkyBackground.self, from: JSONEncoder().encode(sky))
        XCTAssertEqual(decoded, sky)
    }

    func testWidgetPlanetsRespectHorizonAndTwilight() {
        var visibleCount = 0
        var daylightCount = 0
        for hour in 0..<24 {
            let jd = date.julianDate + Double(hour) / 24
            let sun = SkyChartAtmosphere.sun(observer: observer, julianDate: jd)
            let planets = SkyChartUtils.widgetPlanets(observer: observer, julianDate: jd)
            if sun.elev >= -6 {
                daylightCount += 1
                XCTAssertTrue(planets.isEmpty)
            }
            for planet in planets {
                visibleCount += 1
                XCTAssertGreaterThanOrEqual(planet.coordinate.elev, 0)
                XCTAssertTrue(planet.magnitude.isFinite)
                XCTAssertLessThan(sun.elev, planet.body == .venus ? -6 : -12)
                let projected = SkyChartUtils.point(at: planet.coordinate,
                    rect: CGRect(x: 0, y: 0, width: 280, height: 280))
                XCTAssertLessThanOrEqual(hypot(projected.x - 140, projected.y - 140), 140.001)
            }
        }
        XCTAssertGreaterThan(visibleCount, 0)
        XCTAssertGreaterThan(daylightCount, 0)
    }

    private func pass(at date: Date, id: UInt = 25544) -> Pass {
        let jd = date.julianDate
        return Pass(noradIndex: id, rise: .init(julianDate: jd, azim: 0, elev: 0),
            set: .init(julianDate: jd + 0.01, azim: 180, elev: 0),
            culmination: .init(julianDate: jd + 0.005, azim: 90, elev: 60),
            illumination: .init(initiallyIlluminated: true, changes: []), sunElevationAtTransit: -20)
    }

    func testHomeDomeAlwaysPlacesRiseLeftAndSetRightAcrossNorth() {
        let original = pass(at: date)
        for (rise, set, peak) in [(310.0, 145.0, 220.0), (350, 45, 15), (45, 350, 15), (0, 180, 90)] {
            let pass = Pass(noradIndex: original.noradIndex,
                rise: .init(julianDate: original.rise.julianDate, azim: rise, elev: 0),
                set: .init(julianDate: original.set.julianDate, azim: set, elev: 0),
                culmination: .init(julianDate: original.culmination.julianDate, azim: peak, elev: 60),
                illumination: original.illumination, sunElevationAtTransit: -20)
            let projection = ObservationSkyProjection(pass: pass, samples: [], size: CGSize(width: 360, height: 258))
            let start = projection.point(azimuth: rise, elevation: 0)
            let end = projection.point(azimuth: set, elevation: 0)
            let top = projection.point(azimuth: peak, elevation: 60)
            XCTAssertLessThan(start.x, 180)
            XCTAssertGreaterThan(end.x, 180)
            XCTAssertGreaterThanOrEqual(start.x, 14.999)
            XCTAssertLessThanOrEqual(end.x, 345.001)
            XCTAssertEqual(start.y, end.y, accuracy: 0.001)
            XCTAssertLessThan(top.y, start.y)
            XCTAssertTrue(top.x.isFinite && top.y.isFinite)
        }
    }

    func testHomeChoosesMinorArcRegardlessOfCulmination() {
        XCTAssertEqual(ObservationSkyProjection.minorArc(from: 350, to: 10), 20)
        XCTAssertEqual(ObservationSkyProjection.minorArc(from: 10, to: 350), -20)
        XCTAssertEqual(ObservationSkyProjection.minorArc(from: 310, to: 145), -165)
        XCTAssertEqual(ObservationSkyProjection.minorArc(from: 145, to: 310), 165)
        XCTAssertEqual(ObservationSkyProjection.minorArc(from: 0, to: 180), 180)
        let original = pass(at: date)
        let contraryPeak = Pass(noradIndex: original.noradIndex,
            rise: .init(julianDate: original.rise.julianDate, azim: 350, elev: 0),
            set: .init(julianDate: original.set.julianDate, azim: 10, elev: 0),
            culmination: .init(julianDate: original.culmination.julianDate, azim: 180, elev: 80),
            illumination: original.illumination, sunElevationAtTransit: -20)
        let projection = ObservationSkyProjection(pass: contraryPeak, samples: [], size: CGSize(width: 360, height: 258))
        XCTAssertEqual(projection.arc, 20)
        XCTAssertEqual(projection.front.x, 0, accuracy: 1e-10)
        XCTAssertEqual(projection.front.y, 1, accuracy: 1e-10)
    }

    func testDirectSkyRaysAlignWithCatalogAndPreserveLocalShape() {
        let projection = ObservationSkyProjection(pass: pass(at: date), samples: [], size: CGSize(width: 360, height: 258))
        for (azimuth, elevation) in [(30.0, 0.0), (90, 30), (160, 75)] {
            let point = projection.point(azimuth: azimuth, elevation: elevation)
            let ray = projection.direction(at: point)
            XCTAssertEqual(atan2(ray.x, ray.y) * 180 / .pi, azimuth, accuracy: 1e-8)
            XCTAssertEqual(asin(ray.z) * 180 / .pi, elevation, accuracy: 1e-8)
        }
        // Equal tiny angular distances in perpendicular directions must have
        // equal pixel lengths. Independent horizontal/vertical stretching fails.
        let center = projection.point(azimuth: 90, elevation: 30)
        let across = projection.point(azimuth: 90 + 0.01 / cos(.pi / 6), elevation: 30)
        let above = projection.point(azimuth: 90, elevation: 30.01)
        let a = hypot(across.x - center.x, across.y - center.y)
        let b = hypot(above.x - center.x, above.y - center.y)
        XCTAssertEqual(a / b, 1, accuracy: 0.001)
    }

    func testHomeDomeHidesBodiesBehindTheProjectedSky() {
        let projection = ObservationSkyProjection(pass: pass(at: date), samples: [], size: CGSize(width: 360, height: 258))
        XCTAssertNotNil(projection.visiblePoint(azimuth: 90, elevation: 30))
        XCTAssertNil(projection.visiblePoint(azimuth: 270, elevation: 10))
        XCTAssertNil(projection.visiblePoint(azimuth: 90, elevation: -5))
    }

    func testHomeOrdersAcrossStationsAndDeduplicates() {
        let laterISS = pass(at: date.addingTimeInterval(1200))
        let earlierTiangong = pass(at: date.addingTimeInterval(600), id: 48274)
        let expired = pass(at: date.addingTimeInterval(-1800))
        let result = ObservationOpportunity.upcoming([laterISS, earlierTiangong, expired, earlierTiangong], now: date.julianDate)
        XCTAssertEqual(result.map(\.noradIndex), [48274, 25544])
    }

    func testHomeUsesIlluminatedWindowForReminderAndExpiry() {
        let original = pass(at: date)
        let appears = Pass.DatePosition(julianDate: original.rise.julianDate + 0.002, azim: 45, elev: 40)
        let disappears = Pass.DatePosition(julianDate: original.rise.julianDate + 0.007, azim: 135, elev: 30)
        let partial = Pass(noradIndex: original.noradIndex, rise: original.rise, set: original.set,
            culmination: original.culmination,
            illumination: .init(initiallyIlluminated: false, changes: [.exitsShadow(appears), .entersShadow(disappears)]),
            sunElevationAtTransit: -15)
        XCTAssertEqual(ObservationOpportunity.start(partial), appears.julianDate)
        let reminder = ObservationOpportunity.reminder(partial, observer: observer)
        XCTAssertEqual(reminder.alertJulianDate, appears.julianDate - 300.0 / 86400, accuracy: 1e-8)
        XCTAssertTrue(ObservationOpportunity.upcoming([partial], now: disappears.julianDate + 0.0001).isEmpty,
            "Home must not recommend a pass that has already faded but is still above the horizon")
    }

    func testHomeRejectsDaylightAndUnlitPasses() {
        let original = pass(at: date)
        let daylight = Pass(noradIndex: original.noradIndex, rise: original.rise, set: original.set,
            culmination: original.culmination, illumination: original.illumination, sunElevationAtTransit: 5)
        let shadow = Pass(noradIndex: original.noradIndex, rise: original.rise, set: original.set,
            culmination: original.culmination, illumination: .init(initiallyIlluminated: false, changes: []), sunElevationAtTransit: -20)
        XCTAssertTrue(ObservationOpportunity.upcoming([daylight, shadow], now: date.julianDate).isEmpty)
    }

    func testPassPreviewSummarizesVisibleSegmentsAndBestTime() {
        let original = pass(at: date)
        let shadow = Pass.DatePosition(julianDate: original.rise.julianDate + 0.002, azim: 45, elev: 40)
        let light = Pass.DatePosition(julianDate: original.rise.julianDate + 0.008, azim: 135, elev: 20)
        let split = Pass(noradIndex: original.noradIndex, rise: original.rise, set: original.set,
            culmination: original.culmination,
            illumination: .init(initiallyIlluminated: true, changes: [.entersShadow(shadow), .exitsShadow(light)]),
            sunElevationAtTransit: -20)
        XCTAssertEqual(PassPreviewCell.bestViewTime(for: split), shadow.julianDate)
        XCTAssertEqual(PassPreviewCell.visibleDurationSeconds(for: split), 345.6, accuracy: 0.01)
        XCTAssertEqual(PassPreviewCell.bestViewTime(for: original), original.culmination.julianDate)
        XCTAssertEqual(PassPreviewCell.visibleDurationSeconds(for: original), 864, accuracy: 0.01)
        let unlit = Pass(noradIndex: original.noradIndex, rise: original.rise, set: original.set,
            culmination: original.culmination, illumination: .init(initiallyIlluminated: false, changes: []),
            sunElevationAtTransit: -20)
        XCTAssertEqual(PassPreviewCell.visibleDurationSeconds(for: unlit), 0)
        XCTAssertEqual(PassPreviewCell.bestViewTime(for: unlit), unlit.culmination.julianDate)
    }

    func testOrientationGuidanceAcceptsOnlyScreenFacingDown() {
        XCTAssertTrue(DeviceOrientationGuidanceView.isAligned(gravityZ: 1))
        XCTAssertTrue(DeviceOrientationGuidanceView.isAligned(gravityZ: 0.9))
        XCTAssertFalse(DeviceOrientationGuidanceView.isAligned(gravityZ: 0.8))
        XCTAssertFalse(DeviceOrientationGuidanceView.isAligned(gravityZ: 0))
        XCTAssertFalse(DeviceOrientationGuidanceView.isAligned(gravityZ: -1))
        XCTAssertFalse(DeviceOrientationGuidanceView.isAligned(gravityZ: .nan))
    }

    func testPassTimelineUsesHorizonForFullyLitAndDaylightPasses() {
        let original = pass(at: date)
        let events = PassTimelineEvent.events(for: original)
        XCTAssertEqual(events.map(\.title), ["Rises", "Culminates", "Sets"])
        XCTAssertEqual(events.map(\.position), [original.rise, original.culmination, original.set])
        let daylight = Pass(noradIndex: original.noradIndex, rise: original.rise, set: original.set,
            culmination: original.culmination,
            illumination: .init(initiallyIlluminated: false, changes: [.exitsShadow(original.culmination)]),
            sunElevationAtTransit: 20)
        XCTAssertEqual(PassTimelineEvent.events(for: daylight).first?.position, original.rise)
    }

    func testPassTimelineUsesShadowBoundariesAndOmitsHiddenCulmination() {
        let original = pass(at: date)
        let appears = Pass.DatePosition(julianDate: original.rise.julianDate + 0.002, azim: 45, elev: 20)
        let disappears = Pass.DatePosition(julianDate: original.rise.julianDate + 0.007, azim: 120, elev: 30)
        func partial(start: Pass.DatePosition) -> Pass {
            Pass(noradIndex: original.noradIndex, rise: original.rise, set: original.set,
                culmination: original.culmination,
                illumination: .init(initiallyIlluminated: false, changes: [.exitsShadow(start), .entersShadow(disappears)]),
                sunElevationAtTransit: -20)
        }
        let events = PassTimelineEvent.events(for: partial(start: appears))
        XCTAssertEqual(events.map(\.title), ["Becomes visible", "Culminates", "Disappears"])
        XCTAssertEqual(events.map(\.position), [appears, original.culmination, disappears])
        let late = Pass.DatePosition(julianDate: original.rise.julianDate + 0.006, azim: 100, elev: 40)
        XCTAssertEqual(PassTimelineEvent.events(for: partial(start: late)).map(\.title), ["Becomes visible", "Disappears"])
    }

    func testLocationChangeRejectsLateForecast() async {
        let started = expectation(description: "Old forecast started")
        var pending: CheckedContinuation<[Pass], Error>?
        let oldPass = pass(at: date), newPass = pass(at: date.addingTimeInterval(600))
        let model = ForecastModel(client: .init(load: { satellite, request in
            if satellite == .iss && request.observer.lat == 37 {
                return try await withCheckedThrowingContinuation { pending = $0; started.fulfill() }
            }
            return [newPass]
        }, now: { self.date }))
        let old = Task { await model.refresh(.init(observer: observer)) }
        await fulfillment(of: [started], timeout: 1)
        await model.refresh(.init(observer: LatLonAlt(40, -74, 0)))
        pending?.resume(returning: [oldPass])
        await old.value
        XCTAssertEqual(model.issNextPass.content?.nextVisiblePass, newPass)
        XCTAssertEqual(model.upcomingPasses, [newPass])
    }

    func testOneSatelliteFailureDoesNotHideTheOtherAndRetryRecovers() async {
        var fail = true
        let found = pass(at: date)
        let model = ForecastModel(client: .init(load: { satellite, _ in
            if satellite == .iss && fail { throw Failure.offline }
            return [found]
        }, now: { self.date }))
        await model.refresh(.init(observer: observer))
        guard case .failed = model.issNextPass else { return XCTFail("Expected failure") }
        XCTAssertNotNil(model.tianheNextPass.content)
        fail = false
        await model.refresh(.init(observer: observer))
        XCTAssertEqual(model.issNextPass.content?.nextVisiblePass, found)
    }

    func testMissingLocationDoesNotRequestPredictions() async {
        var requests = 0
        let model = ForecastModel(client: .init(load: { _, _ in requests += 1; return [] }))
        await model.refresh(.init())
        XCTAssertEqual(requests, 0)
    }

    func testCancellationDoesNotPublishLateSuccessOrError() async {
        let started = expectation(description: "Request started")
        var pending: CheckedContinuation<[Pass], Error>?
        let model = ForecastModel(client: .init(load: { satellite, _ in
            if satellite == .iss {
                return try await withCheckedThrowingContinuation { pending = $0; started.fulfill() }
            }
            return []
        }))
        let task = Task { await model.refresh(.init(observer: observer)) }
        await fulfillment(of: [started], timeout: 1)
        task.cancel()
        pending?.resume(throwing: Failure.offline)
        await task.value
        guard case .loading = model.issNextPass else { return XCTFail("Cancellation published a result") }
    }

    func testInjectedClockAndOffsetDeterminePredictionWindow() async {
        var requests: [ForecastRequest] = []
        let model = ForecastModel(client: .init(load: { _, request in requests.append(request); return [] }, now: { self.date }))
        await model.refresh(.init(observer: observer, julianDateOffset: 2))
        XCTAssertEqual(requests.count, 2)
        XCTAssertTrue(requests.allSatisfy { $0.dateRange == JulianDateUtil.createJulianDateRange(now: date.julianDate + 2) })
        XCTAssertEqual(model.currentDate, date)
    }

    func testCountdownExpiresPassWithoutReloadingOnEveryTick() async {
        var now = date
        var requests = 0
        var ticks = 0
        let found = pass(at: date)
        let model = ForecastModel(client: .init(load: { _, _ in requests += 1; return [found] },
            now: { now }, sleep: { _ in
                ticks += 1
                if ticks > 1 { throw CancellationError() }
                now = now.addingTimeInterval(900)
            }))
        await model.run(.init(observer: observer))
        XCTAssertEqual(requests, 2)
        XCTAssertNotNil(model.issNextPass.content)
        XCTAssertNil(model.issNextPass.content?.nextVisiblePass)
        XCTAssertTrue(model.upcomingPasses.isEmpty)
    }

    func testHourlyRefreshAdvancesPredictionWindow() async {
        var now = date
        var requests: [ForecastRequest] = []
        var ticks = 0
        let model = ForecastModel(client: .init(load: { _, request in requests.append(request); return [] },
            now: { now }, sleep: { _ in
                ticks += 1
                if ticks > 1 { throw CancellationError() }
                now = now.addingTimeInterval(3600)
            }))
        await model.run(.init(observer: observer))
        XCTAssertEqual(requests.count, 4)
        XCTAssertGreaterThan(requests.last!.dateRange.lowerBound, requests.first!.dateRange.lowerBound)
    }

    func testReturningToPassesKeepsFreshForecastAndUpdatesCountdown() async {
        var now = date
        var requests = 0
        let found = pass(at: date)
        let model = ForecastModel(client: .init(load: { _, _ in requests += 1; return [found] },
            now: { now }, sleep: { _ in throw CancellationError() }))
        let input = ForecastInput(observer: observer)
        await model.run(input)
        now = now.addingTimeInterval(900)
        for _ in 0..<20 { await model.run(input) }
        XCTAssertEqual(requests, 2, "Returning to the tab must not recalculate either station")
        XCTAssertEqual(model.currentDate, now)
        XCTAssertNil(model.issNextPass.content?.nextVisiblePass)
        XCTAssertTrue(model.upcomingPasses.isEmpty, "Expired passes must still disappear")
    }

    func testReturningToPassesRefreshesOnExpiryLocationAndDebugTimeChanges() async {
        var now = date
        var requests = 0
        let model = ForecastModel(client: .init(load: { _, _ in requests += 1; return [] },
            now: { now }, sleep: { _ in throw CancellationError() }))
        var input = ForecastInput(observer: observer)
        await model.run(input)
        now = now.addingTimeInterval(3600)
        await model.run(input)
        XCTAssertEqual(requests, 4)
        input.observer = LatLonAlt(40, -74, 0)
        await model.run(input)
        XCTAssertEqual(requests, 6)
        input.frozenJulianDate = date.julianDate
        await model.run(input)
        XCTAssertEqual(requests, 8)
        await model.refresh(input)
        XCTAssertEqual(requests, 10, "Pull-to-refresh must still force a new calculation")
    }

    func testReturningToPassesRetriesAnInterruptedForecast() async {
        var requests = 0
        var pending: CheckedContinuation<[Pass], Error>?
        let started = expectation(description: "ISS prediction started")
        var interrupt = true
        let model = ForecastModel(client: .init(load: { station, _ in
            requests += 1
            if interrupt && station == .iss {
                return try await withCheckedThrowingContinuation { pending = $0; started.fulfill() }
            }
            return []
        }, sleep: { _ in throw CancellationError() }))
        let input = ForecastInput(observer: observer)
        let first = Task { await model.run(input) }
        await fulfillment(of: [started], timeout: 1)
        first.cancel()
        pending?.resume(returning: [])
        await first.value
        interrupt = false
        await model.run(input)
        XCTAssertEqual(requests, 4)
        XCTAssertNotNil(model.issNextPass.content)
        XCTAssertNotNil(model.tianheNextPass.content)
    }

    func testColdForecastUsesBackendAndPersistsForOfflineLaunch() async throws {
        let folder = try cacheDirectory().appendingPathComponent("nested")
        defer { try? FileManager.default.removeItem(at: folder.deletingLastPathComponent()) }
        let data = tle
        let service = ForecastService(cacheDirectory: folder, fetch: { url in
            guard url.host == "us-central1-pass-prediction.cloudfunctions.net",
                  url.path == "/orbital_data", url.query == "category=25544" else {
                throw ForecastServiceError.invalidResponse
            }
            return data
        })
        let info = try await service.satelliteInfo(for: .iss)
        XCTAssertEqual(info.noradIndex, 25544)
        let offline = OrbitalService(directory: folder, fetch: { _ in throw URLError(.notConnectedToInternet) })
        let cached = try await offline.satellites(.iss, force: true)
        XCTAssertEqual(cached.map(\.noradIndex), [25544])
    }

    func testOMMJSONSupportsSixDigitCatalogNumbersAndFractionalEpoch() throws {
        let data = Data(#"[{"OBJECT_NAME":"NEW SAT","OBJECT_ID":"2026-001A","NORAD_CAT_ID":100001,"EPOCH":"2026-09-15T00:00:00.123456","ECCENTRICITY":0.001,"INCLINATION":51.6,"RA_OF_ASC_NODE":120,"ARG_OF_PERICENTER":20,"MEAN_ANOMALY":30,"MEAN_MOTION":15.5,"BSTAR":0.0001,"EPHEMERIS_TYPE":0,"ELEMENT_SET_NO":999,"REV_AT_EPOCH":1,"CLASSIFICATION_TYPE":"U"}]"#.utf8)
        let elements = try OrbitalDataCache.elements(from: data)
        XCTAssertEqual(elements.first?.noradIndex, 100001)
        XCTAssertTrue(elements[0].n₀.isFinite)
        let wholeSecond = Data(String(decoding: data, as: UTF8.self)
            .replacingOccurrences(of: "00:00:00.123456", with: "00:00:00Z").utf8)
        let wholeElements = try OrbitalDataCache.elements(from: wholeSecond)
        XCTAssertEqual(elements[0].t₀ - wholeElements[0].t₀, 0.123456 / 86400, accuracy: 1e-9)
        let malformedEpoch = Data(String(decoding: data, as: UTF8.self)
            .replacingOccurrences(of: "2026-09-15T00:00:00.123456", with: "invalid").utf8)
        XCTAssertThrowsError(try OrbitalDataCache.elements(from: malformedEpoch))
        let invalid = Data(String(decoding: data, as: UTF8.self).replacingOccurrences(of: "100001", with: "-1").utf8)
        XCTAssertThrowsError(try OrbitalDataCache.elements(from: invalid))
        XCTAssertThrowsError(try OrbitalDataCache.elements(from: Data("[]".utf8)))
    }

    func testAllCategoriesUseAllowlistedBackendDatasets() {
        let pairs: [(SatelliteCategory, String)] = [(.iss, "25544"), (.tianhe, "48274"),
            (.active, "active"), (.brightest100, "visual"), (.last30DayLaunches, "last-30-days")]
        for (category, key) in pairs {
            XCTAssertEqual(category.url.host, "us-central1-pass-prediction.cloudfunctions.net")
            XCTAssertEqual(category.url.query, "category=\(key)")
        }
    }

    func testWhitespaceResponseCannotReplaceCatalogCache() async throws {
        let folder = try cacheDirectory()
        defer { try? FileManager.default.removeItem(at: folder) }
        let file = folder.appendingPathComponent("25544.txt")
        try tle.write(to: file)
        let service = OrbitalService(directory: folder, fetch: { _ in Data("\n\n".utf8) })
        let cached = try await service.satellites(.iss, force: true)
        XCTAssertEqual(cached.map(\.noradIndex), [25544])
        XCTAssertEqual(try Data(contentsOf: file), tle)
    }

    func testFreshCacheAvoidsNetworkAndMatchesDomainPredictions() async throws {
        let folder = try cacheDirectory()
        defer { try? FileManager.default.removeItem(at: folder) }
        try tle.write(to: folder.appendingPathComponent("25544.txt"))
        let network = NetworkProbe()
        let service = ForecastService(cacheDirectory: folder, fetch: { _ in try await network.fetch() })
        let request = ForecastRequest(observer: observer, dateRange: date.julianDate...(date.julianDate + 1))
        let found = try await service.passes(for: .iss, request: request)
        let info = try await service.satelliteInfo(for: .iss)
        let snapshots = try info.generateSnapshots(observer: observer, julianDateRange: request.dateRange)
        let expected = try info.findPasses(observer: observer, coarseSnapshots: snapshots).map(\.pass)
        XCTAssertFalse(found.isEmpty)
        XCTAssertEqual(found, expected)
        let requests = await network.requests
        XCTAssertEqual(requests, 0)
    }

    func testInvalidDownloadPreservesStaleOfflineCache() async throws {
        let folder = try cacheDirectory()
        defer { try? FileManager.default.removeItem(at: folder) }
        let file = folder.appendingPathComponent("25544.txt")
        try tle.write(to: file)
        try FileManager.default.setAttributes([.modificationDate: Date.distantPast], ofItemAtPath: file.path)
        let service = ForecastService(cacheDirectory: folder, fetch: { _ in Data("Error\nInvalid\nResponse".utf8) })
        let info = try await service.satelliteInfo(for: .iss)
        XCTAssertEqual(info.noradIndex, 25544)
        XCTAssertEqual(try Data(contentsOf: file), tle)
    }

    func testCancellationDoesNotFallBackToStaleCache() async throws {
        let folder = try cacheDirectory()
        defer { try? FileManager.default.removeItem(at: folder) }
        let file = folder.appendingPathComponent("25544.txt")
        try tle.write(to: file)
        try FileManager.default.setAttributes([.modificationDate: Date.distantPast], ofItemAtPath: file.path)
        let service = ForecastService(cacheDirectory: folder, fetch: { _ in throw CancellationError() })
        do { _ = try await service.satelliteInfo(for: .iss); XCTFail("Expected cancellation") }
        catch is CancellationError { }
    }

    func testMalformedNumericTLEThrowsInsteadOfTrapping() throws {
        let lines = String(decoding: tle, as: UTF8.self).split(separator: "\n").map(String.init)
        let invalid = lines[1].replacingOccurrences(of: "21152", with: "XX152")
        XCTAssertThrowsError(try Elements(lines[0], invalid, lines[2]))
        XCTAssertThrowsError(try Elements("Invalid", "short", "short"))
    }

    func testPredictionKernelObservesCancellation() async throws {
        let lines = String(decoding: tle, as: UTF8.self).split(separator: "\n").map(String.init)
        let info = try await SatelliteInfo.load(elements: Elements(lines[0], lines[1], lines[2]))
        let task = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            return try info.generateSnapshots(observer: observer, julianDateRange: date.julianDate...(date.julianDate + 7))
        }
        do { _ = try await task.value; XCTFail("Expected cancelled prediction") }
        catch is CancellationError { }
    }

    func testPassListRejectsSupersededObserver() async throws {
        let lines = String(decoding: tle, as: UTF8.self).split(separator: "\n").map(String.init)
        let info = try await SatelliteInfo.load(elements: Elements(lines[0], lines[1], lines[2]))
        let started = expectation(description: "First prediction started")
        let finished = expectation(description: "Second prediction finished")
        var pending: CheckedContinuation<SatelliteTrails, Error>?
        let newObserver = LatLonAlt(40, -74, 0)
        let model = PassListModel(load: { request in
            if request.observer == self.observer {
                return try await withCheckedThrowingContinuation { pending = $0; started.fulfill() }
            }
            finished.fulfill()
            return SatelliteTrails(observer: request.observer, passSnapshots: [])
        })
        func request(_ observer: LatLonAlt) -> CalculatePassesParams {
            .init(selectedNoradIndex: info.noradIndex, satelliteInfo: info, julianDateRange: date.julianDate...(date.julianDate + 1), observer: observer)
        }
        model.send(.calculatePasses(request(observer)))
        await fulfillment(of: [started], timeout: 1)
        model.send(.calculatePasses(request(newObserver)))
        await fulfillment(of: [finished], timeout: 1)
        pending?.resume(returning: SatelliteTrails(observer: observer, passSnapshots: []))
        for _ in 0..<20 { await Task.yield() }
        XCTAssertEqual(model.state.satelliteTrails[info.noradIndex]?.observer, newObserver)
        XCTAssertNil(model.errorMessage)
    }

    func testPassListPublishesFailureAndCanRetry() async throws {
        let lines = String(decoding: tle, as: UTF8.self).split(separator: "\n").map(String.init)
        let info = try await SatelliteInfo.load(elements: Elements(lines[0], lines[1], lines[2]))
        let request = CalculatePassesParams(selectedNoradIndex: info.noradIndex, satelliteInfo: info, julianDateRange: date.julianDate...(date.julianDate + 1), observer: observer)
        var failing = true
        let model = PassListModel(load: { request in
            if failing { throw Failure.offline }
            return SatelliteTrails(observer: request.observer, passSnapshots: [])
        })
        model.send(.calculatePasses(request))
        for _ in 0..<30 { await Task.yield() }
        XCTAssertNotNil(model.errorMessage)
        failing = false
        model.send(.recalculatePasses(request))
        for _ in 0..<30 { await Task.yield() }
        XCTAssertNil(model.errorMessage)
        XCTAssertNotNil(model.state.satelliteTrails[info.noradIndex]?.passSnapshots)
    }

    func testPassPresentationStateIsLocalToEachScreen() {
        let first = PassModel(), second = PassModel()
        first.send(.showAlarmConfiguration(true))
        first.send(.showDetailPassView(true))
        XCTAssertTrue(first.state.showAlarmConfigurationModal)
        XCTAssertTrue(first.state.showsDetailPassView)
        XCTAssertFalse(second.state.showAlarmConfigurationModal)
        XCTAssertFalse(second.state.showsDetailPassView)
    }

    func testOrbitalServiceRejectsInvalidDownloadWithoutReplacingCache() async throws {
        let folder = try cacheDirectory()
        defer { try? FileManager.default.removeItem(at: folder) }
        let file = folder.appendingPathComponent("25544.txt")
        try tle.write(to: file)
        let service = OrbitalService(directory: folder, fetch: { _ in Data("bad response".utf8) })
        let satellites = try await service.satellites(.iss, force: true)
        XCTAssertEqual(satellites.map(\.noradIndex), [25544])
        XCTAssertEqual(try Data(contentsOf: file), tle)
    }

    func testDeepLinkCarriesObserverAndDoesNotOverwriteOtherNavigation() {
        let session = AppSession(catalog: AppStarCatalog())
        session.navigation.forecastPath.append("existing forecast")
        session.open(.brightest100, id: 20580, observer: observer)
        XCTAssertEqual(session.navigation.tab, .satellites)
        XCTAssertEqual(session.navigation.deepLink?.noradIndex, 20580)
        XCTAssertEqual(session.navigation.deepLink?.observer, observer)
        XCTAssertEqual(session.navigation.forecastPath.count, 1)
    }

    func testChartModelKeepsOnlyTheCurrentRenderedImage() async throws {
        let fixture = try await Fixture(catalog: AppStarCatalog())
        let model = SkyChartModel()
        for snapshots in fixture.passes.prefix(3) {
            let key = SkyPathKey(pass: snapshots.pass, isDark: true)
            model.send(.requestRasterizedSatellitePath(size: CGSize(width: 100, height: 100), quality: .preview, passSnapshots: snapshots, traitCollection: UITraitCollection(userInterfaceStyle: .dark)))
            for _ in 0..<100 {
                if model.state.resources.previewSatellitePaths[key] != nil { break }
                try await Task.sleep(for: .milliseconds(10))
            }
            XCTAssertEqual(model.state.resources.previewSatellitePaths.count, 1)
            XCTAssertEqual(model.state.resources.previewSatellitePaths[key]?.size, CGSize(width: 100, height: 100))
        }
    }

    func testSkyNowIncludesHigherOrbits() async throws {
        let folder = try cacheDirectory()
        defer { try? FileManager.default.removeItem(at: folder) }
        let geostationary = String(decoding: tle, as: UTF8.self)
            .replacingOccurrences(of: "25544", with: "40294")
            .replacingOccurrences(of: "15.48954251", with: " 1.00270000")
        let data = Data((String(decoding: tle, as: UTF8.self) + "\n" + geostationary).utf8)
        let service = OrbitalService(directory: folder, fetch: { _ in data })
        let model = RealtimeSkyModel(service: service)
        model.send(.loadElements)
        for _ in 0..<100 {
            if model.state.satellites.content != nil { break }
            try await Task.sleep(for: .milliseconds(10))
        }
        XCTAssertEqual(model.state.satellites.content?.map(\.noradIndex), [25544, 40294])
    }

    func testSkyCatalogRequestsAllActiveWithoutLimit() async throws {
        let folder = try cacheDirectory()
        defer { try? FileManager.default.removeItem(at: folder) }
        let magnitudes = QSMag.localData.values.filter { $0.magnitude != nil && $0.noradIndex < 99999 }
            .sorted { $0.noradIndex < $1.noradIndex }.prefix(150)
        XCTAssertEqual(magnitudes.count, 150)
        let source = String(decoding: tle, as: UTF8.self)
        let data = Data(magnitudes.map {
            source.replacingOccurrences(of: "25544", with: String(format: "%05d", $0.noradIndex))
        }.joined(separator: "\n").utf8)
        let service = OrbitalService(directory: folder, fetch: { url in
            XCTAssertEqual(url, SatelliteCategory.active.url)
            return data
        })
        let catalog = try await service.skyCatalog()
        XCTAssertEqual(catalog.satellites.map(\.noradIndex), magnitudes.map(\.noradIndex))
        XCTAssertEqual(catalog.satellites.count, 150)
        XCTAssertTrue(FileManager.default.fileExists(atPath: folder.appendingPathComponent("active.txt").path))
    }

    func testCatalogEnrichmentStopsAtTheNextRecordAfterCancellation() async throws {
        let lines = String(decoding: tle, as: UTF8.self).split(separator: "\n").map(String.init)
        let element = try Elements(lines[0], lines[1], lines[2])
        let task = Task {
            var enriched = 0
            do {
                _ = try await OrbitalService.enrich(Array(repeating: element, count: 1000)) { element in
                    enriched += 1
                    withUnsafeCurrentTask { $0?.cancel() }
                    return SatelliteInfo(elements: element, satCat: nil, ucsSat: nil, qsMag: nil)
                }
                XCTFail("Cancelled catalog work should stop")
            } catch is CancellationError {
                XCTAssertEqual(enriched, 1, "Do not finish metadata lookups after leaving Sky Now")
            } catch { XCTFail("Unexpected error: \(error)") }
        }
        await task.value
    }

    func testSkyCatalogStaysInMemoryAcrossTabAndLocationChanges() async throws {
        let fixture = try await Fixture(catalog: AppStarCatalog())
        let loaded = expectation(description: "Catalog loaded")
        var requests = 0
        let model = RealtimeSkyModel(state: .init(observer: observer), now: { self.date }, loadCatalog: {
            requests += 1
            loaded.fulfill()
            return ([fixture.info], self.date.addingTimeInterval(21600))
        })
        model.send(.setRealtimeSkyViewActive(true))
        await fulfillment(of: [loaded], timeout: 1)
        for _ in 0..<20 {
            model.send(.setRealtimeSkyViewActive(false))
            model.state.observer = LatLonAlt(40, -74, 0)
            model.send(.setRealtimeSkyViewActive(true))
            model.refreshCatalogIfNeeded()
            await Task.yield()
        }
        XCTAssertEqual(requests, 1, "Tab and observer changes must not reread or reparse the catalog")
        XCTAssertEqual(model.state.satellites.content?.map(\.noradIndex), [25544])
        XCTAssertTrue(model.state.resources.displayResults.isEmpty, "Old positions are discarded independently of elements")
        model.cancel()
    }

    func testSkyCatalogExpiryRefreshesWithoutHidingLoadedElements() async throws {
        let fixture = try await Fixture(catalog: AppStarCatalog())
        var now = date
        var requests = 0
        var pending: CheckedContinuation<(satellites: [SatelliteInfo], refreshAfter: Date), Error>?
        let initial = expectation(description: "Initial load")
        let refresh = expectation(description: "Refresh started")
        let model = RealtimeSkyModel(now: { now }, loadCatalog: {
            requests += 1
            if requests == 1 {
                initial.fulfill()
                return ([fixture.info], now.addingTimeInterval(60))
            }
            return try await withCheckedThrowingContinuation { pending = $0; refresh.fulfill() }
        })
        model.send(.setRealtimeSkyViewActive(true))
        await fulfillment(of: [initial], timeout: 1)
        now = now.addingTimeInterval(60)
        model.refreshCatalogIfNeeded()
        await fulfillment(of: [refresh], timeout: 1)
        for _ in 0..<20 { model.refreshCatalogIfNeeded() }
        XCTAssertEqual(requests, 2, "Repeated timer ticks must share the pending refresh")
        XCTAssertEqual(model.state.satellites.content?.count, 1, "No loading flash during refresh")
        pending?.resume(returning: ([], now.addingTimeInterval(21600)))
        for _ in 0..<100 {
            if model.state.satellites.content?.isEmpty == true { break }
            await Task.yield()
        }
        XCTAssertEqual(model.state.satellites.content?.count, 0)
        model.send(.setRealtimeSkyViewActive(false))
        model.send(.setRealtimeSkyViewActive(true))
        await Task.yield()
        XCTAssertEqual(requests, 2, "An empty successful catalog is cached too")
        model.cancel()
    }

    func testCancelledSkyCatalogCannotReplaceTheResumedLoad() async throws {
        let fixture = try await Fixture(catalog: AppStarCatalog())
        let first = expectation(description: "First request")
        let second = expectation(description: "Resumed request")
        var pending: CheckedContinuation<(satellites: [SatelliteInfo], refreshAfter: Date), Error>?
        var requests = 0
        let model = RealtimeSkyModel(now: { self.date }, loadCatalog: {
            requests += 1
            if requests == 1 {
                return try await withCheckedThrowingContinuation { pending = $0; first.fulfill() }
            }
            second.fulfill()
            return ([], self.date.addingTimeInterval(21600))
        })
        model.send(.setRealtimeSkyViewActive(true))
        await fulfillment(of: [first], timeout: 1)
        model.send(.setRealtimeSkyViewActive(false))
        model.send(.setRealtimeSkyViewActive(true))
        await fulfillment(of: [second], timeout: 1)
        pending?.resume(returning: ([fixture.info], date.addingTimeInterval(21600)))
        for _ in 0..<20 { await Task.yield() }
        XCTAssertEqual(model.state.satellites.content?.count, 0)
        model.refreshCatalogIfNeeded()
        XCTAssertEqual(requests, 2)
        model.cancel()
    }

    func testSkyMemoryCacheUsesTheOriginalDiskExpiry() async throws {
        let folder = try cacheDirectory()
        defer { try? FileManager.default.removeItem(at: folder) }
        let file = folder.appendingPathComponent(SatelliteCategory.active.localFilename).appendingPathExtension("txt")
        try tle.write(to: file)
        let downloaded = Date().addingTimeInterval(-5 * 3600)
        try FileManager.default.setAttributes([.modificationDate: downloaded], ofItemAtPath: file.path)
        let network = NetworkProbe()
        let service = OrbitalService(directory: folder, fetch: { _ in try await network.fetch() })
        let catalog = try await service.skyCatalog()
        XCTAssertEqual(catalog.refreshAfter.timeIntervalSince(downloaded), 21600, accuracy: 1)
        let requests = await network.requests
        XCTAssertEqual(requests, 0)
        XCTAssertEqual(catalog.satellites.map(\.noradIndex), [25544])
    }

    func testSatelliteDestinationSurvivesCatalogReloadAndRemoval() async throws {
        let lines = String(decoding: tle, as: UTF8.self).split(separator: "\n").map(String.init)
        let info = try await SatelliteInfo.load(elements: Elements(lines[0], lines[1], lines[2]))
        let satellites = Map([(info.noradIndex, info)])
        let model = SatelliteListModel(state: .init(satelliteInfo: [.iss: .loaded(satellites)]))
        var rendered: SatelliteInfo?
        let list = SatelliteListView(
            viewModel: model,
            context: .init(category: .iss, julianDateRange: date.julianDate...(date.julianDate + 1),
                observer: nil, starManager: .init(), julianDateProvider: { self.date.julianDate }),
            allPassesViewFactory: .init { context in
                rendered = context.satelliteInfo
                return AllPassesView(viewModel: .init(), context: context,
                    skyChartFactory: .crash, passViewFactory: .crash)
            })
        let destination = list.satelliteDestination(.init(noradIndex: info.noradIndex), in: satellites)
        // SwiftUI may evaluate the lazy destination while a pop transition reloads its parent.
        for state: Loadable<Map<UInt, SatelliteInfo>, ElementsLoaderError> in [.loading, .loaded(Map())] {
            model.state.satelliteInfo[.iss] = state
            rendered = nil
            let renderer = ImageRenderer(content: destination.frame(width: 402, height: 874))
            _ = renderer.uiImage
            XCTAssertEqual(rendered, info)
        }
        rendered = nil
        let missing = list.satelliteDestination(.init(noradIndex: 0), in: satellites)
        _ = ImageRenderer(content: missing).uiImage
        XCTAssertNil(rendered)
    }

    func testReturningToSatelliteListKeepsLoadedCatalogButRetryReloads() async throws {
        let lines = String(decoding: tle, as: UTF8.self).split(separator: "\n").map(String.init)
        let info = try await SatelliteInfo.load(elements: Elements(lines[0], lines[1], lines[2]))
        let model = SatelliteListModel(state: .init(satelliteInfo: [.iss: .loaded(Map([(info.noradIndex, info)]))]))
        model.load(.iss)
        XCTAssertEqual(model.state.satelliteInfo[.iss]?.content?[info.noradIndex], info)
        model.load(.iss, force: true)
        guard case .loading = model.state.satelliteInfo[.iss] else { return XCTFail("Retry must reload") }
        model.cancel()
    }

    func testSatelliteSearchDoesNotPublishASupersededQuery() async throws {
        let lines = String(decoding: tle, as: UTF8.self).split(separator: "\n").map(String.init)
        let info = try await SatelliteInfo.load(elements: Elements(lines[0], lines[1], lines[2]))
        let model = SatelliteListModel(state: .init(satelliteInfo: [.iss: .loaded(Map([(info.noradIndex, info)]))]))
        model.send(.searchSatellites("ISS", category: .iss))
        model.send(.searchSatellites("not a satellite", category: .iss))
        for _ in 0..<100 {
            if model.state.filteredSatellites != nil { break }
            try await Task.sleep(for: .milliseconds(10))
        }
        XCTAssertEqual(model.state.filteredSatellites?.count, 0)
        model.send(.searchSatellites("", category: .iss))
        XCTAssertNil(model.state.filteredSatellites)
    }

    func testSkyLocationChangeDoesNotLeavePredictionPermanentlyBusy() async throws {
        let fixture = try await Fixture(catalog: AppStarCatalog())
        let started = expectation(description: "Prediction started")
        var pending: CheckedContinuation<[RealtimePropagationResult], Error>?
        let model = RealtimeSkyModel(state: .init(observer: observer), predict: { _, _, _ in
            try await withCheckedThrowingContinuation { pending = $0; started.fulfill() }
        })
        model.send(.propagateCurrentEphemerides([fixture.info], observer: observer, julianDate: date.julianDate))
        await fulfillment(of: [started], timeout: 1)
        model.state.observer = LatLonAlt(40, -74, 0)
        pending?.resume(returning: [])
        for _ in 0..<100 {
            if !model.state.resources.isPropagatingEphemerides { break }
            await Task.yield()
        }
        XCTAssertFalse(model.state.resources.isPropagatingEphemerides)
        XCTAssertTrue(model.state.resources.displayResults.isEmpty)
    }

    func testHorizonRechecksBeforeRiseAgainstDensePropagation() async throws {
        let lines = String(decoding: tle, as: UTF8.self).split(separator: "\n").map(String.init)
        let info = SatelliteInfo(elements: try Elements(lines[0], lines[1], lines[2]))
        var deferred = 0
        for site in [observer, LatLonAlt(0, 0, 0), LatLonAlt(70, 20, 2)] {
            // Independent one-second SGP4 reference covering more than one LEO orbit.
            let samples = try (0...7200).map { second in
                try info.generateSnapshot(julianDate: date.julianDate + Double(second) / 86400, observer: site)
            }
            for second in stride(from: 0, through: 6900, by: 10) {
                let sample = samples[second]
                guard sample.position.elev < -1 else { continue }
                let delay = OrbitalService.horizonRecheckDelay(elevation: sample.position.elev,
                    distance: sample.position.dist, observerAltitude: site.alt)
                if delay > 30 { deferred += 1 }
                for offset in 0...Int(delay) {
                    XCTAssertLessThanOrEqual(samples[second + offset].position.elev, 0,
                        "A satellite rose before its scheduled recheck at offset \(second), delay \(delay)")
                }
            }
        }
        XCTAssertGreaterThan(deferred, 100, "Well-below-horizon objects should skip many frames")
        XCTAssertEqual(OrbitalService.horizonRecheckDelay(elevation: -.infinity, distance: 1000, observerAltitude: 0), 0.5)
        XCTAssertEqual(OrbitalService.horizonRecheckDelay(elevation: -0.1, distance: 1000, observerAltitude: 0), 0.5)
    }

    func testSkyQueueOnlyPropagatesDueCandidatesIncludingExactDeadline() async throws {
        let lines = String(decoding: tle, as: UTF8.self).split(separator: "\n").map(String.init)
        let satellites = try (30000..<30200).map { id in
            SatelliteInfo(elements: try Elements(lines[0], lines[1].replacingOccurrences(of: "25544", with: "\(id)"),
                lines[2].replacingOccurrences(of: "25544", with: "\(id)")))
        }
        var batches: [[UInt]] = []
        let start = date.julianDate
        let model = RealtimeSkyModel(state: .init(observer: observer), predict: { candidates, site, time in
            batches.append(candidates.map(\.noradIndex))
            return try candidates.map { info in
                .init(noradIndex: info.noradIndex,
                    snapshot: try info.generateSnapshot(julianDate: time, observer: site), satelliteInfo: info,
                    nextCheckJulianDate: time + (info.noradIndex < 30002 ? 1 : 300) / 86400)
            }
        })
        func tick(_ time: Double) async {
            model.send(.propagateCurrentEphemerides(satellites, observer: observer, julianDate: time))
            for _ in 0..<1000 where model.state.resources.isPropagatingEphemerides { await Task.yield() }
            XCTAssertFalse(model.state.resources.isPropagatingEphemerides)
        }
        await tick(start)
        await tick(start + 0.5 / 86400)
        XCTAssertEqual(batches.count, 1, "No work should be scheduled before the earliest deadline")
        await tick(start + 1 / 86400)
        XCTAssertEqual(batches.map(\.count), [200, 2])
        XCTAssertEqual(Set(batches[1]), [30000, 30001])
        XCTAssertEqual(model.state.resources.results.count, 200, "Due entries must be replaced, not duplicated")
        await tick(start - 1 / 86400)
        XCTAssertEqual(batches.last?.count, 200, "Backward clock changes invalidate deferred work")
    }

    private func cacheDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}

private enum Failure: Error { case offline, unexpectedNetwork }
private let tle = Data("""
ISS (ZARYA)
1 25544U 98067A   21152.92855006  .00000952  00000-0  25634-4 0  9993
2 25544  51.6442 295.0433 0002767  53.3435  75.5612 15.48954251286176
""".utf8)

private actor NetworkProbe {
    private(set) var requests = 0
    func fetch() throws -> Data { requests += 1; throw Failure.unexpectedNetwork }
}
