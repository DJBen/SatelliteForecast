import XCTest
import SwiftUI
import CoreLocation
import CoreMotion
import BTree
import CombineRex
import CombineRextensions
import SwiftRex
@testable import SatelliteForecastApp
import SatelliteForecast
@testable import SatelliteForecastImpl
import SatelliteForecastImplWiring
import SatelliteKit

/// Native view snapshots at a fixed phone size, locale, timezone and orbital epoch.
/// No live store middleware, location permissions, notifications or network loaders.
@MainActor
final class ScreenSnapshotTests: XCTestCase {
    private let size = CGSize(width: 402, height: 874)
    private let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()

    func testAllScreensLightAndDark() async throws {
        UserDefaults.standard.set(true, forKey: "hasCompletedAllPassesOnboarding")
        NSTimeZone.default = TimeZone(secondsFromGMT: 0)!
        UIView.setAnimationsEnabled(false)
        defer { UIView.setAnimationsEnabled(true) }
        let catalog = try await AppStarCatalog.load()
        for style in [UIUserInterfaceStyle.light, .dark] {
            let fixture = try Fixture(catalog: catalog)
            for (name, view) in fixture.screens() {
                let selected = ProcessInfo.processInfo.environment["SNAPSHOT_SCREEN"] ?? ""
                if !selected.isEmpty && !selected.split(separator: ",").contains(where: { name.hasPrefix($0) }) { continue }
                try await assertSnapshot(view, name: "\(name)-\(style == .dark ? "dark" : "light")", style: style)
            }
        }
    }

    private func assertSnapshot(_ view: AnyView, name: String, style: UIUserInterfaceStyle) async throws {
        let host = UIHostingController(rootView: view
            .environment(\.motionManagerKey, CMMotionManager())
            .environment(\.locale, Locale(identifier: "en_US"))
            .environment(\.timeZone, TimeZone(secondsFromGMT: 0)!)
            .environment(\.colorScheme, style == .dark ? .dark : .light)
            .environment(\.dynamicTypeSize, .large)
            .transaction { $0.animation = nil })
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.first as? UIWindowScene)
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(origin: .zero, size: size)
        window.overrideUserInterfaceStyle = style
        window.rootViewController = host
        window.makeKeyAndVisible()
        host.view.frame = window.bounds
        host.view.setNeedsLayout()
        host.view.layoutIfNeeded()
        // Allow SwiftUI layout, async star labels and UIKit navigation to settle.
        try await Task.sleep(for: .milliseconds(800))
        host.view.layoutIfNeeded()
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let image = UIGraphicsImageRenderer(size: size, format: format).image { _ in
            host.view.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
        }
        window.isHidden = true
        window.rootViewController = nil
        let attachment = XCTAttachment(image: image)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
        let mode = ProcessInfo.processInfo.environment["SNAPSHOT_RECORD"] ?? ""
        let folder = root.appendingPathComponent("Documentation/DesignReview/\(mode == "before" ? "before" : "after")")
        let url = folder.appendingPathComponent(name + ".png")
        let data = try XCTUnwrap(image.pngData())
        if mode == "before" || mode == "after" {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            try data.write(to: url)
        } else {
            let baseline = try XCTUnwrap(UIImage(contentsOfFile: url.path), "Missing baseline: \(url.path). Record and review it explicitly.")
            XCTAssertEqual(baseline.size, image.size, name)
            let difference = try pixelDifference(baseline, image)
            XCTAssertLessThan(difference, 0.004, "\(name): average pixel difference \(difference)")
        }
    }

    private func pixelDifference(_ lhs: UIImage, _ rhs: UIImage) throws -> Double {
        func pixels(_ image: UIImage) throws -> [UInt8] {
            let cg = try XCTUnwrap(image.cgImage)
            var result = [UInt8](repeating: 0, count: cg.width * cg.height * 4)
            let context = try XCTUnwrap(CGContext(data: &result, width: cg.width, height: cg.height,
                bitsPerComponent: 8, bytesPerRow: cg.width * 4, space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
            context.draw(cg, in: CGRect(x: 0, y: 0, width: cg.width, height: cg.height))
            return result
        }
        let a = try pixels(lhs), b = try pixels(rhs)
        guard a.count == b.count else { return 1 }
        return Double(zip(a, b).reduce(0) { $0 + abs(Int($1.0) - Int($1.1)) }) / Double(a.count * 255)
    }
}

@MainActor
struct Fixture {
    let catalog: AppStarCatalog
    let now = Date(timeIntervalSince1970: 1622592000) // 2021-06-02, near the TLE epoch
    let observer = LatLonAlt(37.486743, -122.226560, 0)
    let info: SatelliteInfo
    let passes: [PassSnapshots]
    let textResource: EphemerideResource
    let store: ReduxStoreBase<AppAction, AppState>
    var range: ClosedRange<Double> { now.julianDate...(now.julianDate + 7) }

    init(catalog: AppStarCatalog) throws {
        self.catalog = catalog
        let elements = try Elements("ISS (ZARYA)",
            "1 25544U 98067A   21152.92855006  .00000952  00000-0  25634-4 0  9993",
            "2 25544  51.6442 295.0433 0002767  53.3435  75.5612 15.48954251286176")
        let textURL = FileManager.default.temporaryDirectory.appendingPathComponent("snapshot-ephemeris.tle")
        try "ISS (ZARYA)\n1 25544U 98067A   21152.92855006  .00000952  00000-0  25634-4 0  9993\n2 25544  51.6442 295.0433 0002767  53.3435  75.5612 15.48954251286176".write(to: textURL, atomically: true, encoding: .utf8)
        textResource = EphemerideResource(fileName: "ISS.tle", fullPath: textURL.path, size: 160, modificationDate: nil)
        info = try SatelliteInfo(elements: elements)
        let snapshots = try info.generateSnapshots(observer: observer, julianDateRange: now.julianDate...(now.julianDate + 7))
        passes = try info.findPasses(observer: observer, coarseSnapshots: snapshots)
        var state = AppState()
        state.onboardingState.hasCompletedOnboarding = true
        state.showExperimentalSkyNow = true
        state.locationResources = .init(authorizationStatus: .authorizedWhenInUse,
            currentLocation: CLLocation(latitude: observer.lat, longitude: observer.lon))
        state.elementsLoader.info[.iss] = .loaded(Map([(elements.noradIndex, info)]))
        state.elementsLoader.info[.brightest100] = .loaded(Map([(elements.noradIndex, info)]))
        state.elementsPropagatorResources.satelliteTrails[elements.noradIndex] = SatelliteTrails(observer: observer, snapshots: snapshots, passSnapshots: passes)
        state.backgroundSkyResources.allConstellations = Array(catalog.allConstellations())
        store = ReduxStoreBase(
            subject: .combine(initialValue: state),
            reducer: Store.reducer,
            middleware: EffectMiddleware.backgroundSky.lift(dependencies: catalog)
                <> EffectMiddleware.skyChart.lift()
                <> EffectMiddleware.satelliteElevationGraph.lift(),
            emitsValue: .whenDifferent
        )
    }

    func screens() -> [(String, AnyView)] {
        let pass = passes.first { $0.pass.sunElevationAtTransit < -6 && ($0.pass.highestIlluminated?.elev ?? 0) > 10 } ?? passes[0]
        let date = { now.julianDate }
        let nextPass = NextPass(nextVisiblePass: pass.pass, nextProminentPass: pass.pass)
        let overview = SatelliteOverviewViewImpl(viewModel: .mock(state: .init(observer: observer,
            issNextPass: .loaded(nextPass), tianheNextPass: .loaded(nextPass), authorizationStatus: .authorizedWhenInUse)),
            context: .init(starManager: catalog, julianDateProvider: date), singleSatelliteWrappingViewProducer: .singleSatelliteWrappingView(viewModel: store))
        return [
            ("01-welcome", AnyView(OnboardingView(onComplete: {}))),
            ("02-predictions-intro", AnyView(OnboardingView(initialPage: 1, onComplete: {}))),
            ("03-forecast", AnyView(overview)),
            ("04-satellites", AnyView(ViewProducer.satelliteCategory(viewModel: store).view(.init(starManager: catalog, julianDateProvider: date)))),
            ("05-satellite-list", AnyView(NavigationStack { ViewProducer.satelliteListView(viewModel: store).view(.init(category: .brightest100, julianDateRange: range, observer: observer, starManager: catalog, julianDateProvider: date)) })),
            ("06-pass-forecast", AnyView(NavigationStack { ViewProducer.allPassesView(viewModel: store).view(.init(satelliteInfo: info, julianDateRange: range, observer: observer, starManager: catalog, julianDateProvider: date)) })),
            ("07-pass", AnyView(NavigationStack { ViewProducer.passView(viewModel: store).view(.init(passIndex: 0, satelliteInfo: info, satelliteCommonName: "ISS (ZARYA)", category: .iss, julianDateRange: range, observer: observer, passSnapshots: pass, starManager: catalog, julianDateProvider: date)) })),
            ("08-detailed-sky", AnyView(ViewProducer.detailedPassView(viewModel: store).view(.init(satelliteInfo: info, category: .iss, julianDateRange: range, observer: observer, passSnapshots: pass, starManager: catalog, julianDateProvider: date)))),
            ("09-sky-now", AnyView(ViewProducer.realtimeSky(viewModel: store).view(.init(basicChartConfigs: .init(), backgroundSkyConfigs: .preset, satelliteMagToRadiusFunction: .default, starManager: catalog, julianDateProvider: { pass.pass.rise.julianDate })))),
            ("10-settings", AnyView(ViewProducer.settingsOverview(viewModel: store).view())),
            ("11-location", AnyView(NavigationStack { ViewProducer.locationSettings(viewModel: store).view() })),
            ("12-alarms", AnyView(NavigationStack { ViewProducer.alarmSettingsView(viewModel: store).view() })),
            ("13-pass-alarm", AnyView(ViewProducer.passAlarmSettings(viewModel: store).view(.init(satelliteName: "ISS (ZARYA)", category: .iss, passSnapshots: pass, observer: observer)))),
            ("14-ephemerides", AnyView(NavigationStack { EphemeridesManagementView() })),
            ("15-star-detail", AnyView(NavigationStack { SelectedStarLabel(starManager: catalog, star: catalog.brightestStars()[0]).padding().navigationTitle("Star details") })),
            ("17-mission-control", AnyView(MissionControlView(satelliteInfo: info, julianDateProvider: date, julianDateOffset: 0, userLocation: CLLocation(latitude: observer.lat, longitude: observer.lon)))),
            ("18-ephemeris-text", AnyView(NavigationStack { EphemerideTextBrowserView(resource: textResource) })),
            ("19-pass-tutorial", AnyView(AllPassesOnboardingView(onComplete: {}, skyChartProducer: .skyChart(viewModel: store), satelliteData: SatelliteData(satelliteInfo: info, observer: observer, selectedPass: pass)))),
            ("20-debug", AnyView(DebugMenu(viewModel: .mock(state: DebugMenuState(trueJulianDate: now.julianDate, config: .init(), pendingNotifications: [], deliveredNotifications: [], fcmToken: nil))))),
            ("16-night-mode", AnyView(ViewProducer.settingsOverview(viewModel: store).view().overlay(Color.red.blendMode(.plusDarker).allowsHitTesting(false)))),
        ]
    }
}
