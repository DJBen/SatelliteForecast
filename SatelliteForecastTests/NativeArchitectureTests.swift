import CoreLocation
import MapKit
import SwiftUI
import Observation
import XCTest
import SatelliteForecast
@testable import SatelliteForecastImpl
import SatelliteKit
import simd
@testable import SatelliteForecastApp

@MainActor
final class NativeArchitectureTests: XCTestCase {
    func testOfflineGeographicContext() async throws {
        let lookup = GeographicRegionLookup()
        for (latitude, longitude, name) in [(48.85, 2.35, "France"),
                                            (35.68, 139.69, "Japan"),
                                            (-18.14, 178.44, "Fiji"),
                                            (1.35, 103.82, "Singapore")] {
            let result = await lookup.summary(latitude: latitude, longitude: longitude)
            XCTAssertEqual(result?.name, name)
            XCTAssertEqual(result?.isWater, false)
            XCTAssertNotNil(result?.flag)
            XCTAssertEqual(result?.compactDescription(locale: Locale(identifier: "en")), "Over \(name)")
        }
        let ocean = await lookup.summary(latitude: 0, longitude: -140)
        XCTAssertTrue(ocean?.name.contains("Pacific") == true)
        XCTAssertTrue(ocean?.detail(locale: Locale(identifier: "en")).contains("km") == true)
        XCTAssertNil(ocean?.flag)
        XCTAssertFalse(ocean?.compactDescription(locale: Locale(identifier: "en")).contains("km") == true)
        let japan = await lookup.summary(latitude: 35.68, longitude: 139.69)
        XCTAssertEqual(japan?.flag, "🇯🇵")
        let east = await lookup.summary(latitude: 0, longitude: 180)
        let west = await lookup.summary(latitude: 0, longitude: -180)
        XCTAssertEqual(east, west)
        let wrapped = await lookup.summary(latitude: 0, longitude: 220)
        XCTAssertEqual(wrapped, ocean)
        let invalid = await lookup.summary(latitude: .nan, longitude: 0)
        XCTAssertNil(invalid)
    }

    func testGeographicLocalization() async throws {
        let lookup = GeographicRegionLookup()
        let japanResult = await lookup.summary(latitude: 35.68, longitude: 139.69)
        let japan = try XCTUnwrap(japanResult)
        let expected = ["en": "Over Japan", "fr": "À la verticale : Japon",
                        "es": "Sobre: Japón", "pt-BR": "Sobre: Japão",
                        "ru": "Под спутником: Япония", "ja": "日本の上空",
                        "ko": "일본 상공", "zh-Hans": "日本上空"]
        for (language, text) in expected {
            let locale = Locale(identifier: language)
            XCTAssertEqual(japan.compactDescription(locale: locale), text)
            XCTAssertEqual(japan.flag, "🇯🇵")
            XCTAssertFalse(GeographicLocalization.text("unavailable", locale: locale).contains("geography."))
        }
        XCTAssertEqual(japan.compactDescription(locale: Locale(identifier: "fr-CA")), expected["fr"])
        XCTAssertEqual(japan.compactDescription(locale: Locale(identifier: "pt_BR")), expected["pt-BR"])
        XCTAssertEqual(japan.compactDescription(locale: Locale(identifier: "de-DE")), expected["en"])
        let englishOnly = GeographicRegionLookup.Place(names: ["en": "Example Sea"], countryCode: nil)
        XCTAssertEqual(englishOnly.name(locale: Locale(identifier: "ru")), "Example Sea")
        let near = GeographicRegionLookup.Summary(place: englishOnly, isWater: true,
            nearestLand: japan.place, distanceKilometers: 200, bearingDegrees: 90)
        XCTAssertEqual(near.compactDescription(locale: Locale(identifier: "ja")), "Example Sea・日本付近")
        XCTAssertFalse(near.compactDescription(locale: Locale(identifier: "fr")).contains("200"))
        let fallback = GeographicRegionLookup.Summary(place: nil, isWater: false,
            nearestLand: japan.place, distanceKilometers: 10, bearingDegrees: 0)
        XCTAssertEqual(fallback.compactDescription(locale: Locale(identifier: "ko")), "일본 인근")
        let distant = GeographicRegionLookup.Summary(place: englishOnly, isWater: true,
            nearestLand: japan.place, distanceKilometers: 1234, bearingDegrees: 90)
        XCTAssertTrue(distant.detail(locale: Locale(identifier: "ru")).contains("восток"))
        XCTAssertTrue(distant.detail(locale: Locale(identifier: "ru")).contains("км"))
        let pacificResult = await lookup.summary(latitude: 0, longitude: -140)
        let pacific = try XCTUnwrap(pacificResult)
        XCTAssertEqual(pacific.compactDescription(locale: Locale(identifier: "zh-CN")), "太平洋上空")
    }

    func testSubdivisionsAndShortCountryNames() async throws {
        let lookup = GeographicRegionLookup()
        for (lat, lon, expected, flag) in [
            (34.05, -118.24, "Over California, US", "🇺🇸"),
            (30.27, -97.74, "Over Texas, US", "🇺🇸"),
            (43.65, -79.38, "Over Ontario, Canada", "🇨🇦"),
            (-27.47, 153.02, "Over Queensland, Australia", "🇦🇺"),
            (19.08, 72.88, "Over Maharashtra, India", "🇮🇳"),
            (25.20, 55.27, "Over UAE", "🇦🇪"),
            (51.51, -0.13, "Over UK", "🇬🇧")
        ] {
            let result = await lookup.summary(latitude: lat, longitude: lon)
            XCTAssertEqual(result?.compactDescription(locale: Locale(identifier: "en")), expected)
            XCTAssertEqual(result?.flag, flag)
        }
        let california = await lookup.summary(latitude: 34.05, longitude: -118.24)
        XCTAssertEqual(california?.compactDescription(locale: Locale(identifier: "fr")), "À la verticale : Californie, USA")
        XCTAssertEqual(california?.compactDescription(locale: Locale(identifier: "zh-Hans")), "美国·加利福尼亚州上空")
        // Offshore proximity still refers to a country, not an inland state boundary.
        let country = GeographicRegionLookup.Place(names: ["en": "United States of America"], countryCode: "US")
        let sea = GeographicRegionLookup.Place(names: ["en": "Pacific Ocean"], countryCode: nil)
        let offshore = GeographicRegionLookup.Summary(place: sea, isWater: true,
            nearestLand: country, distanceKilometers: 200, bearingDegrees: 90)
        XCTAssertEqual(offshore.compactDescription(locale: Locale(identifier: "en")), "Pacific Ocean · near US")
        XCTAssertEqual(country.countryName(locale: Locale(identifier: "ru")), "США")
        let fallback = GeographicRegionLookup.Summary(place: country, isWater: false,
            nearestLand: nil, distanceKilometers: nil, bearingDegrees: nil)
        XCTAssertEqual(fallback.compactDescription(locale: Locale(identifier: "en")), "Over US")
    }

    func testRootTabVisibilityUpdatesWithoutLegacyStore() async throws {
        // Root configures application-wide UIKit appearance. Restore it so this test
        // cannot change the independent screen snapshot fixtures that run afterward.
        let navigation = UINavigationBar.appearance()
        let standard = navigation.standardAppearance
        let compact = navigation.compactAppearance
        let scrollEdge = navigation.scrollEdgeAppearance
        let tabBarAppearance = UITabBar.appearance()
        let tabBackground = tabBarAppearance.backgroundColor
        let tabTint = tabBarAppearance.unselectedItemTintColor
        defer {
            navigation.standardAppearance = standard
            navigation.compactAppearance = compact
            navigation.scrollEdgeAppearance = scrollEdge
            tabBarAppearance.backgroundColor = tabBackground
            tabBarAppearance.unselectedItemTintColor = tabTint
        }
        let settings = AppSettings()
        let root = RootView(
            selectedTab: .constant(.forecast), settings: settings,
            context: RootViewContext(starManager: AppStarCatalog(), julianDateProvider: { 0 }),
            realtimeSkyViewFactory: { _ in EmptySky() },
            satelliteOverviewViewFactory: { _ in EmptyForecast() },
            satelliteCategoryViewFactory: { _ in EmptySatellites() },
            settingsOverviewFactory: { EmptySettings() })
        let host = UIHostingController(rootView: root)
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.first as? UIWindowScene)
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(x: 0, y: 0, width: 402, height: 874)
        window.rootViewController = host
        window.makeKeyAndVisible()
        defer { window.isHidden = true; window.rootViewController = nil }
        func tabBar(in view: UIView) -> UITabBar? {
            if let bar = view as? UITabBar { return bar }
            return view.subviews.lazy.compactMap { tabBar(in: $0) }.first
        }
        for (visible, count) in [(false, 3), (true, 4), (false, 3)] {
            settings.showExperimentalSkyNow = visible
            for _ in 0..<20 {
                host.view.layoutIfNeeded()
                if tabBar(in: host.view)?.items?.count == count { break }
                try await Task.sleep(for: .milliseconds(50))
            }
            XCTAssertEqual(try XCTUnwrap(tabBar(in: host.view)).items?.count, count)
        }
    }

    func testSharedSettingsNotifyBothAppearanceConsumers() {
        let settings = AppSettings()
        let overlay = expectation(description: "Night overlay observes settings")
        let settingsScreen = expectation(description: "Settings screen observes settings")
        withObservationTracking {
            _ = settings.isNightModeOn
        } onChange: {
            overlay.fulfill()
        }
        withObservationTracking {
            _ = settings.isNightModeOn
        } onChange: {
            settingsScreen.fulfill()
        }
        settings.isNightModeOn = true
        wait(for: [overlay, settingsScreen], timeout: 1)
    }

    func testSkyVisibilityDoesNotInvalidateNightAppearance() {
        let settings = AppSettings()
        let nightChanged = expectation(description: "Unrelated appearance stays untouched")
        nightChanged.isInverted = true
        withObservationTracking {
            _ = settings.isNightModeOn
        } onChange: {
            nightChanged.fulfill()
        }
        settings.showExperimentalSkyNow = true
        wait(for: [nightChanged], timeout: 0.05)
        XCTAssertTrue(settings.showExperimentalSkyNow)
    }

    func testLocationSelectionDoesNotPopUnrelatedNavigation() {
        let navigation = AppNavigation()
        let location = LocationService(openSettings: {})
        navigation.forecastPath.append("existing forecast")
        navigation.satelliteCategoryNavigationPath.append("existing category")
        let completion = MKLocalSearchCompletion()
        let placemark = MKPlacemark(coordinate: CLLocationCoordinate2D(latitude: 37, longitude: -122))
        let selected = LocationResources.Selection.custom(completion, placemark)
        // Previously this action unconditionally removed an entry from Settings' global path,
        // trapping when dispatched without a presented location screen.
        location.select(selected)
        guard case .custom = location.resources.selection else {
            return XCTFail("Expected custom location selection")
        }
        XCTAssertEqual(location.resources.location?.coordinate.latitude, 37)
        XCTAssertEqual(location.resources.location?.coordinate.longitude, -122)
        XCTAssertEqual(navigation.forecastPath.count, 1)
        XCTAssertEqual(navigation.satelliteCategoryNavigationPath.count, 1)
    }

    func testUnavailableCurrentLocationKeepsExistingSelection() {
        let navigation = AppNavigation()
        let location = LocationService(openSettings: {})
        let selected = LocationResources.Selection.custom(
            MKLocalSearchCompletion(),
            MKPlacemark(coordinate: CLLocationCoordinate2D(latitude: 37, longitude: -122)))
        location.resources.selection = selected
        location.resources.currentLocation = nil
        location.select(.currentLocation)
        guard case .custom = location.resources.selection else {
            return XCTFail("Expected custom location selection")
        }
        XCTAssertEqual(location.resources.location?.coordinate.latitude, 37)
        XCTAssertEqual(location.resources.location?.coordinate.longitude, -122)
    }
}

private struct EmptySky: RealtimeSkyView { var body: some View { Color.clear } }
private struct EmptyForecast: SatelliteOverviewView { var body: some View { Color.clear } }
private struct EmptySatellites: SatelliteCategoryView { var body: some View { Color.clear } }
private struct EmptySettings: SettingsOverviewView { var body: some View { Color.clear } }

@MainActor
final class MilkyWayProjectionTests: XCTestCase {
    func testGalacticCenterAndNorthPoleRegistration() {
        func vector(_ ra: Double, _ dec: Double) -> SIMD3<Double> {
            let a = ra * deg2rad, d = dec * deg2rad
            return SIMD3(cos(d) * cos(a), cos(d) * sin(a), sin(d))
        }
        let center = MilkyWayBackground.galactic(vector(266.4049948, -28.936174))
        XCTAssertEqual(center.x, 1, accuracy: 1e-6)
        XCTAssertEqual(center.y, 0, accuracy: 1e-6)
        XCTAssertEqual(center.z, 0, accuracy: 1e-6)
        let pole = MilkyWayBackground.galactic(vector(192.85948, 27.12825))
        XCTAssertEqual(pole.z, 1, accuracy: 1e-10)
    }

    func testProjectionMatchesCatalogAcrossObserversAndTimes() {
        let rect = CGRect(x: 20, y: 40, width: 480, height: 600)
        for latitude in [-89.0, -33.9, 0, 37.49, 89] {
            for jd in [2451545.0, 2461297.5, 2461297.75] {
                let observer = LatLonAlt(latitude, -122.23, 0)
                let projection = MilkyWayBackground.Projection(observer: observer, julianDate: jd)
                for coordinate in [RADec(266.405, -28.936), RADec(0, 0), RADec(310.35, 45.28)] {
                    let horizontal = azel(julianDate: jd, site: (observer.lat, observer.lon), cele: coordinate)
                    let screen = SkyChartUtils.point(at: horizontal, rect: rect)
                    let inverse = SkyChartUtils.aziEle(at: screen, in: rect)
                    let actual = projection.equatorial(at: inverse)
                    let a = coordinate.ra * deg2rad, d = coordinate.dec * deg2rad
                    XCTAssertLessThan(simd_length(actual - SIMD3(cos(d) * cos(a), cos(d) * sin(a), sin(d))), 1e-9)
                }
            }
        }
    }

    func testNASATextureRegistrationAndSeam() throws {
        let uv = MilkyWayBackground.textureCoordinates
        XCTAssertEqual(uv(SIMD3(1, 0, 0)), SIMD2(0.5, 0.5))
        XCTAssertEqual(uv(SIMD3(0, 1, 0)), SIMD2(0.25, 0.5))
        XCTAssertEqual(uv(SIMD3(0, -1, 0)), SIMD2(0.75, 0.5))
        XCTAssertEqual(uv(SIMD3(0, 0, 1)).y, 0)
        XCTAssertEqual(uv(SIMD3(0, 0, -1)).y, 1)
        let texture = try XCTUnwrap(MilkyWayBackground.texture)
        XCTAssertEqual(texture.width, 1024)
        XCTAssertEqual(texture.height, 512)
        XCTAssertLessThan(simd_length(texture.sample(SIMD2(1 - 1e-10, 0.5)) - texture.sample(SIMD2(1e-10, 0.5))), 1e-6)
        XCTAssertGreaterThan(simd_length(texture.sample(SIMD2(0.5, 0.45))), simd_length(texture.sample(SIMD2(0.5, 0))))
    }

    func testSmoothingSuppressesFineGrainAndPreservesMean() throws {
        var bytes = [UInt8]()
        for y in 0..<16 {
            for x in 0..<16 {
                let value: UInt8 = (x+y).isMultiple(of: 2) ? 80 : 160
                bytes += [value, value, value, 255]
            }
        }
        let provider = try XCTUnwrap(CGDataProvider(data: Data(bytes) as CFData))
        let image = try XCTUnwrap(CGImage(width: 16, height: 16, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: 64,
            space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
            provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent))
        let texture = try XCTUnwrap(MilkyWayBackground.Texture(image: image)).smoothed(radius: 2)
        let values = stride(from: 0, to: texture.pixels.count, by: 4).map { Double(texture.pixels[$0]) }
        XCTAssertLessThan(values.max()! - values.min()!, 20)
        XCTAssertEqual(values.reduce(0,+) / Double(values.count), 120, accuracy: 1)
        XCTAssertLessThan(simd_distance(texture.sample(SIMD2(0.00000001,0.5)), texture.sample(SIMD2(0.99999999,0.5))), 0.00001)
    }

    func testTextureDecodePreservesNorthAndSouthAndWrapsLongitude() throws {
        let bytes: [UInt8] = [255, 0, 0, 255, 0, 255, 0, 255, 0, 0, 255, 255, 255, 255, 255, 255]
        let provider = try XCTUnwrap(CGDataProvider(data: Data(bytes) as CFData))
        let image = try XCTUnwrap(CGImage(width: 2, height: 2, bitsPerComponent: 8, bitsPerPixel: 32,
            bytesPerRow: 8, space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
            provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent))
        let texture = try XCTUnwrap(MilkyWayBackground.Texture(image: image))
        XCTAssertEqual(texture.sample(SIMD2(0.25, 0)), SIMD3(1, 0, 0))
        XCTAssertEqual(texture.sample(SIMD2(0.25, 1)), SIMD3(0, 0, 1))
        XCTAssertEqual(texture.sample(SIMD2(0, 0)), SIMD3(0.5, 0.5, 0))
        XCTAssertEqual(texture.sample(SIMD2(1, 0)), texture.sample(SIMD2(0, 0)))
    }

    func testRasterIsBoundedTransparentOutsideHorizonAndDeterministic() throws {
        let observer = LatLonAlt(37.49, -122.23, 0)
        let first = try XCTUnwrap(MilkyWayBackground.image(size: CGSize(width: 900, height: 900), observer: observer, julianDate: 2461297.5, dark: true))
        let second = try XCTUnwrap(MilkyWayBackground.image(size: CGSize(width: 900, height: 900), observer: observer, julianDate: 2461297.5, dark: true))
        XCTAssertEqual(first.cgImage?.width, 512)
        XCTAssertEqual(first.pngData(), second.pngData())
        let data = try XCTUnwrap(first.cgImage?.dataProvider?.data) as Data
        XCTAssertEqual(data[3], 0)
        XCTAssertTrue(stride(from: 3, to: data.count, by: 4).contains { data[$0] > 0 })
    }
}

@MainActor
final class MoonAppearanceTests: XCTestCase {
    private func jd(_ iso: String) -> Double { ISO8601DateFormatter().date(from: iso)!.julianDate }

    func testKnownLunarPhases() {
        // Published 2024 phase instants, Fred Espenak's Sky Event Almanac.
        let samples = [("2024-04-08T18:21:00Z", 0.0), ("2024-04-15T19:13:00Z", 0.5),
                       ("2024-04-23T23:49:00Z", 1.0), ("2024-05-01T11:27:00Z", 0.5)]
        for (date, fraction) in samples {
            let moon = MoonAppearance.Geometry(julianDate: jd(date), observer: LatLonAlt(37.49, -122.23, 0))
            XCTAssertEqual(moon.illuminatedFraction, fraction, accuracy: 0.035, date)
        }
    }

    func testChartOrientationAcrossHemispheresAndPoles() {
        let rect = CGRect(x: 0, y: 0, width: 400, height: 400)
        let time = jd("2024-04-11T04:00:00Z")
        for latitude in [-89.9, -33.9, 0, 37.49, 89.9] {
            let site = LatLonAlt(latitude, -122.23, 0)
            let moon = MoonAppearance.Geometry(julianDate: time, observer: site)
            XCTAssertEqual(simd_length(moon.light), 1, accuracy: 1e-10)
            XCTAssertEqual(simd_dot(moon.right, moon.down), 0, accuracy: 1e-10)
            // Screen y points down, so right × down points away from the viewer.
            XCTAssertEqual(simd_dot(simd_cross(moon.right, moon.down), moon.towardViewer), -1, accuracy: 1e-10)
            // Project a small step along each computed icon axis. It must move
            // right/down in the actual chart, including its east-left convention.
            let direction = -moon.towardViewer
            let origin = SkyChartUtils.point(at: moon.coordinate, rect: rect)
            for (axis, horizontal) in [(moon.right, true), (moon.down, false)] {
                let coordinate = azel(time: Date(julianDate: time), site: LatLon(site), cele: RADec(direction + axis * 1e-6))
                let point = SkyChartUtils.point(at: coordinate, rect: rect)
                XCTAssertGreaterThan(horizontal ? point.x - origin.x : point.y - origin.y, 0)
            }
            let body = moon.body
            XCTAssertEqual(simd_determinant(body), 1, accuracy: 1e-10)
            let earth = body.transpose * simd_normalize(-lunarCel(julianDays: time))
            XCTAssertLessThan(abs(atan2(earth.y, earth.x) * rad2deg), 12, "Near side must face Earth")
            XCTAssertLessThan(abs(asin(earth.z) * rad2deg), 10)
        }
    }

    func testTextureRasterAndEarthshine() throws {
        let texture = try XCTUnwrap(MoonAppearance.texture)
        XCTAssertEqual(texture.width, 512)
        XCTAssertEqual(texture.height, 256)
        let time = jd("2024-04-11T04:00:00Z")
        let night = MoonAppearance.Geometry(julianDate: time, observer: LatLonAlt(37.49, -122.23, 0))
        let day = MoonAppearance.Geometry(julianDate: time, observer: LatLonAlt(37.49, 120, 0))
        XCTAssertLessThan(night.sunElevation, -6)
        XCTAssertGreaterThan(day.sunElevation, 2)
        func pixels(_ geometry: MoonAppearance.Geometry) throws -> [UInt8] {
            let image = try XCTUnwrap(MoonAppearance.image(geometry: geometry, dimension: 96)?.cgImage)
            XCTAssertEqual(image.width, 96)
            return Array(try XCTUnwrap(image.dataProvider?.data) as Data)
        }
        let dark = try pixels(night), bright = try pixels(day)
        XCTAssertEqual(dark[3], 0, "Outside the lunar limb stays transparent")
        let center = (48 * 96 + 48) * 4
        XCTAssertGreaterThan(dark[center], 0, "Earthshine reveals the dark face")
        XCTAssertLessThan(dark[center], 70, "Earthshine must remain faint")
        XCTAssertEqual(bright[center + 3], 0, "Daytime sky shows through the unlit face")
        XCTAssertEqual(dark, try pixels(night), "Deterministic raster")
    }
}


@MainActor
final class AnalyticsTests: XCTestCase {
    func testOperationHasOneTerminalOutcomeAndDuration() {
        var events: [(String, AppAnalytics.Screen, [String: Any])] = []
        let operation = AppAnalytics.Operation("calculate_passes", screen: .passes) {
            events.append(($0, $1, $2))
        }
        operation.finish("success", count: 3)
        operation.finish("cancelled") // Deferred cleanup must not overwrite success.
        XCTAssertEqual(events.map { $0.0 }, ["operation_started", "operation_finished"])
        XCTAssertTrue(events.allSatisfy { $0.1 == .passes })
        XCTAssertEqual(events[1].2["outcome"] as? String, "success")
        XCTAssertEqual(events[1].2["result_count"] as? Int, 3)
        XCTAssertGreaterThanOrEqual(events[1].2["duration_ms"] as? Double ?? -1, 0)
        XCTAssertEqual(Set(events[1].2.keys), ["operation", "outcome", "duration_ms", "result_count"])
    }

    func testBlockedAndCancelledAreNotSuccess() {
        for outcome in ["blocked", "cancelled", "failure", "empty"] {
            var terminal: [String: Any] = [:]
            let operation = AppAnalytics.Operation("schedule_alarm", screen: .alarmSetup) { name, _, values in
                if name == "operation_finished" { terminal = values }
            }
            operation.finish(outcome, reason: outcome == "blocked" ? "notification_permission_denied" : nil)
            XCTAssertEqual(terminal["outcome"] as? String, outcome)
            XCTAssertNil(terminal["result_count"])
        }
    }
}
