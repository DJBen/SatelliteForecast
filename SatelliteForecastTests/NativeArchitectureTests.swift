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
        XCTAssertEqual(texture.width, 2048)
        XCTAssertEqual(texture.height, 1024)
        XCTAssertLessThan(simd_length(texture.sample(SIMD2(1 - 1e-10, 0.5)) - texture.sample(SIMD2(1e-10, 0.5))), 1e-6)
        XCTAssertGreaterThan(simd_length(texture.sample(SIMD2(0.5, 0.45))), simd_length(texture.sample(SIMD2(0.5, 0))))
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
