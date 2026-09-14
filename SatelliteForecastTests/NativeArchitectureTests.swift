import CoreLocation
import MapKit
import SwiftUI
import Observation
import XCTest
import SatelliteForecast
import SatelliteForecastImpl
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
            realtimeSkyViewProducer: { _ in EmptySky() },
            satelliteOverviewViewProducer: { _ in EmptyForecast() },
            satelliteCategoryViewProducer: { _ in EmptySatellites() },
            settingsOverviewProducer: { EmptySettings() })
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
        var state = AppState()
        state.navigationState.passPredictionNavigationPath.append("existing forecast")
        state.navigationState.satelliteCategoryNavigationPath.append("existing category")
        let completion = MKLocalSearchCompletion()
        let placemark = MKPlacemark(coordinate: CLLocationCoordinate2D(latitude: 37, longitude: -122))
        let selected = LocationResources.Selection.custom(completion, placemark)
        // Previously this action unconditionally removed an entry from Settings' global path,
        // trapping when dispatched without a presented location screen.
        Store.reducer.reduce(.location(.selectLocation(selected)), &state)
        guard case .custom = state.locationResources.selection else {
            return XCTFail("Expected custom location selection")
        }
        XCTAssertEqual(state.locationResources.location?.coordinate.latitude, 37)
        XCTAssertEqual(state.locationResources.location?.coordinate.longitude, -122)
        XCTAssertEqual(state.navigationState.passPredictionNavigationPath.count, 1)
        XCTAssertEqual(state.navigationState.satelliteCategoryNavigationPath.count, 1)
    }

    func testUnavailableCurrentLocationKeepsExistingSelection() {
        var state = AppState()
        let selected = LocationResources.Selection.custom(
            MKLocalSearchCompletion(),
            MKPlacemark(coordinate: CLLocationCoordinate2D(latitude: 37, longitude: -122)))
        state.locationResources.selection = selected
        state.locationResources.currentLocation = nil
        Store.reducer.reduce(.location(.selectLocation(.currentLocation)), &state)
        guard case .custom = state.locationResources.selection else {
            return XCTFail("Expected custom location selection")
        }
        XCTAssertEqual(state.locationResources.location?.coordinate.latitude, 37)
        XCTAssertEqual(state.locationResources.location?.coordinate.longitude, -122)
    }
}

private struct EmptySky: RealtimeSkyView { var body: some View { Color.clear } }
private struct EmptyForecast: SatelliteOverviewView { var body: some View { Color.clear } }
private struct EmptySatellites: SatelliteCategoryView { var body: some View { Color.clear } }
private struct EmptySettings: SettingsOverviewView { var body: some View { Color.clear } }
