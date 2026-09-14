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
        delegate.onDeepLink = { _, id, location in
            received.append(id)
            XCTAssertEqual(location, observer)
        }
        XCTAssertEqual(received, [25544])
        delegate.onDeepLink = { _, id, _ in received.append(id) }
        XCTAssertEqual(received, [25544], "Buffered links are drained exactly once")
    }

}
