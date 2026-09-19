import XCTest
import StarryNight
import UIKit
@testable import SatelliteForecastApp
import SatelliteKit
import SatelliteForecast
@testable import SatelliteForecastImpl

final class CatalogIntegrationTests: XCTestCase {
    func testAppLoadsNewCatalogWithCompleteConstellationEndpoints() async throws {
        let catalog = try await AppStarCatalog.load()
        XCTAssertEqual(catalog.brightestStars().count, 299)
        XCTAssertGreaterThan(catalog.stars(maximumMagnitude: 6).count, 299)
        for constellation in catalog.allConstellations() {
            for line in catalog.constellationLines(for: constellation) {
                XCTAssertNotNil(catalog.star(withId: line.star1Id))
                XCTAssertNotNil(catalog.star(withId: line.star2Id))
            }
        }
        let first = try XCTUnwrap(catalog.brightestStars().first)
        XCTAssertEqual(catalog.closestStar(to: first.coordinate, maximumMagnitude: 6, maximumAngularDistance: 0)?.id, first.id)
        let info = try await catalog.starInfo(forId: first.id)
        XCTAssertNotNil(info?.properName)
    }

    func testRenderingUsesImmutableDataAcrossConcurrentWorkers() async throws {
        let catalog = try await AppStarCatalog.load()
        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<20 {
                group.addTask {
                    XCTAssertEqual(catalog.brightestStars().count, 299)
                    XCTAssertFalse(catalog.allConstellations().isEmpty)
                    XCTAssertTrue(catalog.stars(maximumMagnitude: 4.5).allSatisfy { $0.magnitude <= 4.5 })
                }
            }
        }
    }
}

@MainActor
final class AppearanceIntegrationTests: XCTestCase {
    func testBackgroundAndPathCachesSeparateLightAndDarkImages() async throws {
        let catalog = try await AppStarCatalog.load()
        let fixture = try Fixture(catalog: catalog)
        let light = BackgroundSkyKey(observer: fixture.observer, configs: .preset, isDark: false)
        let dark = BackgroundSkyKey(observer: fixture.observer, configs: .preset, isDark: true)
        XCTAssertNotEqual(light, dark)
        XCTAssertEqual(Set([light, dark]).count, 2)
        let pass = try XCTUnwrap(fixture.passes.first).pass
        let lightPath = SkyPathKey(pass: pass, isDark: false)
        let darkPath = SkyPathKey(pass: pass, isDark: true)
        var resources = SkyChartResources()
        resources.previewSatellitePaths[lightPath] = UIImage()
        resources.previewSatellitePaths[darkPath] = UIImage()
        XCTAssertEqual(resources.previewSatellitePaths.count, 2)
    }

    func testSemanticTextAndActionColorsHaveReadableContrast() {
        func luminance(_ color: UIColor, _ style: UIUserInterfaceStyle) -> CGFloat {
            let resolved = color.resolvedColor(with: UITraitCollection(userInterfaceStyle: style))
            var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
            resolved.getRed(&r, green: &g, blue: &b, alpha: &a)
            func linear(_ c: CGFloat) -> CGFloat { c <= 0.04045 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4) }
            return 0.2126 * linear(r) + 0.7152 * linear(g) + 0.0722 * linear(b)
        }
        for style in [UIUserInterfaceStyle.light, .dark] {
            for foreground in [AppTheme.accentColor, AppTheme.mutedColor] {
                for background in [AppTheme.backgroundColor, AppTheme.surfaceColor] {
                    let f = luminance(foreground, style), b = luminance(background, style)
                    XCTAssertGreaterThanOrEqual((max(f, b) + 0.05) / (min(f, b) + 0.05), 4.5)
                }
            }
        }
    }

    func testLaunchEventsAreDeliveredAfterCatalogLoading() {
        let delegate = AppDelegate()
        delegate.dispatch(.didRegisterForRemoteNotificationsWithDeviceToken(Data([1])))
        var count = 0
        delegate.onLifecycle = { _ in count += 1 }
        XCTAssertEqual(count, 1)
        delegate.dispatch(.didRegisterForRemoteNotificationsWithDeviceToken(Data([2])))
        XCTAssertEqual(count, 2)
    }
    func testNotificationDeepLinkIsBufferedUntilTheNativeSessionIsReady() {
        let delegate = AppDelegate()
        let observer = LatLonAlt(37, -122, 0)
        delegate.dispatchNotificationAction(.deepLink(category: .iss, noradIndex: 25544, observer: observer, passIdentifier: "test"))
        var received: [UInt] = []
        delegate.onDeepLink = { _, id, location, _ in
            received.append(id)
            XCTAssertEqual(location, observer)
        }
        XCTAssertEqual(received, [25544])
        delegate.onDeepLink = { _, id, _, _ in received.append(id) }
        XCTAssertEqual(received, [25544], "Buffered links are drained exactly once")
    }

}

@MainActor
final class DeepLinkTests: XCTestCase {
    private func payload(_ id: String = "25544", time: String? = nil) -> [AnyHashable: Any] {
        var data: [AnyHashable: Any] = ["noradIndex": id,
            "satelliteCategory": id == "25544" ? "iss" : "tianhe",
            "lat": "37.49", "lon": "-122.23", "alt": "0"]
        data["passTime"] = time
        return data
    }

    func testLegacyAndTimedNotificationsForBothStations() throws {
        for id in ["25544", "48274"] {
            let legacy = try XCTUnwrap(SatelliteDeepLink(userInfo: payload(id)))
            XCTAssertEqual(legacy.noradIndex, UInt(id))
            XCTAssertNil(legacy.passTime)
            let timed = try XCTUnwrap(SatelliteDeepLink(userInfo: payload(id, time: "1789714800")))
            XCTAssertEqual(timed.passTime?.timeIntervalSince1970, 1789714800)
            XCTAssertEqual(timed.category.noradIndex, UInt(id))
        }
    }

    func testLocalAlarmObserverAndPassTime() throws {
        var data = payload(time: "1789714800")
        let observer = LatLonAlt(35.6, 139.7, 40)
        data["observer"] = try JSONEncoder().encode(observer)
        XCTAssertEqual(SatelliteDeepLink(userInfo: data)?.observer, observer)
    }

    func testURLsForBothStationsAndNumericAliases() throws {
        for (name, id) in [("iss", 25544), ("25544", 25544), ("tiangong", 48274), ("48274", 48274)] {
            let base = "satelliteforecast://satellite/\(name)?lat=37.49&lon=-122.23"
            let legacy = try XCTUnwrap(SatelliteDeepLink(url: URL(string: base)!))
            XCTAssertEqual(legacy.noradIndex, UInt(id))
            XCTAssertNil(legacy.passTime)
            let timed = try XCTUnwrap(SatelliteDeepLink(url: URL(string: base + "&time=2026-09-18T07:00:00Z")!))
            XCTAssertEqual(timed.passTime, ISO8601DateFormatter().date(from: "2026-09-18T07:00:00Z"))
        }
    }

    func testInvalidInputsDoNotNavigate() {
        for (key, value) in [("lat", "nan"), ("lat", "91"), ("lon", "181"),
                             ("alt", "inf"), ("passTime", "bad"), ("passTime", "nan"),
                             ("satelliteCategory", "tianhe"), ("noradIndex", "0")] {
            var data = payload()
            data[key] = value
            XCTAssertNil(SatelliteDeepLink(userInfo: data), key)
        }
        for url in ["https://satellite/iss?lat=0&lon=0",
                    "satelliteforecast://satellite/unknown?lat=0&lon=0",
                    "satelliteforecast://satellite/iss?lat=0&lat=1&lon=0",
                    "satelliteforecast://satellite/iss?lat=0&lon=0&time=bad"] {
            XCTAssertNil(SatelliteDeepLink(url: URL(string: url)!))
        }
    }

    func testTimedTapSurvivesColdStartBuffer() {
        let delegate = AppDelegate()
        let time = Date(timeIntervalSince1970: 1789714800)
        for (category, id) in [(SatelliteCategory.iss, UInt(25544)), (.tianhe, UInt(48274))] {
            delegate.dispatchNotificationAction(.deepLink(category: category, noradIndex: id,
                observer: LatLonAlt(37.49, -122.23, 0), passIdentifier: "test", passTime: time))
        }
        var ids: [UInt] = []
        delegate.onDeepLink = { _, id, _, date in ids.append(id); XCTAssertEqual(date, time) }
        XCTAssertEqual(ids, [25544, 48274])
        delegate.onDeepLink = { _, _, _, _ in XCTFail("Must drain only once") }
    }

    func testURLSurvivesCatalogLoading() {
        let delegate = AppDelegate()
        delegate.open(URL(string: "satelliteforecast://satellite/tiangong?lat=0&lon=0&time=2026-09-18T07:00:00Z")!)
        var links: [SatelliteDeepLink] = []
        delegate.onURL = { links.append($0) }
        XCTAssertEqual(links.count, 1)
        XCTAssertEqual(links.first?.noradIndex, 48274)
        XCTAssertNotNil(links.first?.passTime)
        delegate.onURL = { _ in XCTFail("Must drain only once") }
    }

    func testPassMatchingAcceptsSmallDriftButNotAdjacentOrbit() {
        let rise = 2461301.0, set = 2461301.01
        XCTAssertTrue(DeepLinkPassResolver.contains(rise: rise, set: set, time: rise + 0.005))
        XCTAssertTrue(DeepLinkPassResolver.contains(rise: rise, set: set, time: rise - 2.0 / 1440))
        XCTAssertFalse(DeepLinkPassResolver.contains(rise: rise, set: set, time: rise + 90.0 / 1440))
        XCTAssertFalse(DeepLinkPassResolver.contains(rise: rise, set: set, time: .nan))
    }
}

final class LocalizationTests: XCTestCase {
    func testCompiledResourcesContainGuidanceAndFormatsInEveryLanguage() throws {
        let locales = ["en", "fr", "es", "pt-BR", "ru", "zh-Hans", "ja", "ko"]
        let keys = ["Lift your iPhone", "Camera up. Screen down.", "Show orientation guidance",
                    "Dismiss orientation guidance", "Unable to open pass", "Loading the sky…",
                    "Moon", "Constellation labels", "Pass preview time", "Pause preview"]
        for locale in locales {
            let url = try XCTUnwrap(AppLocalization.bundle.url(forResource: locale, withExtension: "lproj"))
            let bundle = try XCTUnwrap(Bundle(url: url))
            for key in keys {
                let value = bundle.localizedString(forKey: key, value: "MISSING", table: nil)
                XCTAssertNotEqual(value, "MISSING", "\(locale): \(key)")
                if locale != "en" { XCTAssertNotEqual(value, key, "\(locale): untranslated \(key)") }
            }
            let format = bundle.localizedString(forKey: "The orbital data does not contain satellite %@.", value: nil, table: nil)
            let message = String(format: format, locale: Locale(identifier: locale), "25544")
            XCTAssertTrue(message.contains("25544"))
            XCTAssertFalse(message.contains("%@"))
        }
        XCTAssertEqual(AppLocalization.text("a deliberately unknown key"), "a deliberately unknown key")
    }
}
