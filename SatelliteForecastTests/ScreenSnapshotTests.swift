import XCTest
import SwiftUI
import CoreLocation
import CoreMotion
import BTree
@testable import SatelliteForecastApp
import SatelliteForecast
@testable import SatelliteForecastImpl
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
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("snapshot-empty-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        for style in [UIUserInterfaceStyle.light, .dark] {
            let fixture = try Fixture(catalog: catalog)
            for (name, view) in fixture.screens() {
                let selected = ProcessInfo.processInfo.environment["SNAPSHOT_SCREEN"] ?? ""
                if !selected.isEmpty && !selected.split(separator: ",").contains(where: { name.hasPrefix($0) }) { continue }
                try await assertSnapshot(AnyView(view.environment(\.ephemerisDirectory, directory)), name: "\(name)-\(style == .dark ? "dark" : "light")", style: style)
            }
        }
    }

    /// Full-resolution store captures are separate from regression baselines.
    func testAppStoreScreenshots() async throws {
        let env = ProcessInfo.processInfo.environment
        guard let destination = env["STORE_SCREENSHOT_OUTPUT"] else { throw XCTSkip("Run scripts/capture-store-screenshots.py") }
        let locale = env["STORE_SCREENSHOT_LOCALE"] ?? "en-US"
        let previousTimeZone = NSTimeZone.default
        NSTimeZone.default = TimeZone(identifier: "America/Los_Angeles")!
        defer { NSTimeZone.default = previousTimeZone }
        UserDefaults.standard.set(true, forKey: "hasCompletedAllPassesOnboarding")
        UIView.setAnimationsEnabled(false)
        defer { UIView.setAnimationsEnabled(true) }
        let catalog = try await AppStarCatalog.load()
        let fixtureURL = root.appendingPathComponent("SatelliteForecastTests/Fixtures/AppStore")
        func tle(_ name: String) throws -> [String] {
            try String(contentsOf: fixtureURL.appendingPathComponent(name), encoding: .utf8)
                .split(whereSeparator: \.isNewline).map(String.init)
        }
        let now = ISO8601DateFormatter().date(from: "2026-09-14T08:00:00Z")!
        let fixture = try Fixture(catalog: catalog, now: now, tle: tle("iss.tle"))
        let tianhe = try tle("tiangong.tle")
        let info = try SatelliteInfo(elements: Elements(tianhe[0], tianhe[1], tianhe[2]))
        let snapshots = try info.generateSnapshots(observer: fixture.observer, julianDateRange: fixture.range)
        let passes = try info.findPasses(observer: fixture.observer, coarseSnapshots: snapshots)
        let featured = ["ja", "ko", "zh-Hans"].contains(locale) ? try Fixture(catalog: catalog, now: now, tle: tianhe) : fixture
        let screens = fixture.storeScreens(tianhePasses: passes, featured: featured)
        let selectedScreens = env["STORE_SCREENSHOT_SCREENS"]?.split(separator: ",").map(String.init)
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.first as? UIWindowScene)
        let folder = URL(fileURLWithPath: destination).appendingPathComponent(locale)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let window = UIWindow(windowScene: scene)
        window.frame = scene.screen.bounds
        window.overrideUserInterfaceStyle = .dark
        let host = StoreHostingController(rootView: AnyView(Color.clear))
        window.rootViewController = host
        window.makeKeyAndVisible()
        defer { window.isHidden = true; window.rootViewController = nil }
        for (name, view) in screens {
            if let selectedScreens, !selectedScreens.contains(name) { continue }
            host.rootView = AnyView(view.id(name)
                .environment(\.motionManagerKey, CMMotionManager())
                .environment(\.locale, Locale(identifier: locale))
                .environment(\.timeZone, TimeZone(identifier: "America/Los_Angeles")!)
                .environment(\.colorScheme, .dark)
                .environment(\.dynamicTypeSize, .large)
                .transaction { $0.animation = nil })
            host.setNeedsStatusBarAppearanceUpdate()
            host.view.frame = window.bounds
            host.view.layoutIfNeeded()
            // Allow actual MapKit tiles and actor-rendered star charts to finish.
            try await Task.sleep(for: .seconds(name.hasPrefix("03") ? 12 : 4))
            // The CLI captures the actual simulator screen, including native status/tab bars.
            // Hosted unit tests cannot call XCUIScreen (it requires a UI-test runner).
            let ready = folder.appendingPathComponent("capture-ready.txt")
            let acknowledgement = folder.appendingPathComponent("capture-done.txt")
            try? FileManager.default.removeItem(at: acknowledgement)
            try name.write(to: ready, atomically: true, encoding: .utf8)
            var captured = false
            for _ in 0..<300 {
                if FileManager.default.fileExists(atPath: acknowledgement.path) { captured = true; break }
                try await Task.sleep(for: .milliseconds(200))
            }
            XCTAssertTrue(captured, "Capture runner did not acknowledge \(name)")
            try? FileManager.default.removeItem(at: acknowledgement)
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
            if difference >= 0.004 {
                let failures = FileManager.default.temporaryDirectory.appendingPathComponent("SatelliteForecastSnapshotFailures")
                try FileManager.default.createDirectory(at: failures, withIntermediateDirectories: true)
                let actual = failures.appendingPathComponent(name + ".png")
                try data.write(to: actual)
                print("Snapshot actual: \(actual.path)")
            }
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
    let now: Date
    let observer = LatLonAlt(37.486743, -122.226560, 0)
    let info: SatelliteInfo
    let passes: [PassSnapshots]
    let textResource: EphemerideResource
    let session: AppSession
    let trails: SatelliteTrails
    var factory: ScreenFactory { ScreenFactory(session: session) }
    var range: ClosedRange<Double> { now.julianDate...(now.julianDate + 7) }

    init(catalog: AppStarCatalog, now: Date = Date(timeIntervalSince1970: 1622592000), tle: [String]? = nil) throws {
        self.catalog = catalog
        self.now = now
        let elements = try tle.map { try Elements($0[0], $0[1], $0[2]) } ?? Elements("ISS (ZARYA)",
            "1 25544U 98067A   21152.92855006  .00000952  00000-0  25634-4 0  9993",
            "2 25544  51.6442 295.0433 0002767  53.3435  75.5612 15.48954251286176")
        let textURL = FileManager.default.temporaryDirectory.appendingPathComponent("snapshot-ephemeris.tle")
        try "ISS (ZARYA)\n1 25544U 98067A   21152.92855006  .00000952  00000-0  25634-4 0  9993\n2 25544  51.6442 295.0433 0002767  53.3435  75.5612 15.48954251286176".write(to: textURL, atomically: true, encoding: .utf8)
        textResource = EphemerideResource(fileName: "ISS.tle", fullPath: textURL.path, size: 160, modificationDate: nil)
        info = try SatelliteInfo(elements: elements)
        let snapshots = try info.generateSnapshots(observer: observer, julianDateRange: now.julianDate...(now.julianDate + 7))
        passes = try info.findPasses(observer: observer, coarseSnapshots: snapshots)
        trails = SatelliteTrails(observer: observer, snapshots: snapshots, passSnapshots: passes)
        session = AppSession(catalog: catalog, location: LocationService(resources: .init(authorizationStatus: .authorizedWhenInUse, currentLocation: CLLocation(latitude: observer.lat, longitude: observer.lon))))
        session.settings.showExperimentalSkyNow = true

    }

    func screens() -> [(String, AnyView)] {
        let pass = passes.first { $0.pass.sunElevationAtTransit < -6 && ($0.pass.highestIlluminated?.elev ?? 0) > 10 } ?? passes[0]
        let date = { now.julianDate }
        let nextPass = NextPass(nextVisiblePass: pass.pass, nextProminentPass: pass.pass)
        let forecast = ForecastModel(client: .init(load: { _, _ in [] }, now: { now }),
                                     issNextPass: .loaded(nextPass), tianheNextPass: .loaded(nextPass))
        let overview = SatelliteOverviewViewImpl(model: forecast,
            input: .init(observer: observer, authorizationStatus: .authorizedWhenInUse),
            navigationPath: .constant(NavigationPath()),
            context: .init(starManager: catalog, julianDateProvider: date),
            singleSatelliteWrappingViewFactory: { factory.detail($0) })
        return [
            ("01-welcome", AnyView(OnboardingView(onComplete: {}))),
            ("02-predictions-intro", AnyView(OnboardingView(initialPage: 1, onComplete: {}))),
            ("03-forecast", AnyView(overview)),
            ("04-satellites", AnyView(SatelliteCategoryViewImpl(viewModel: .init(state: .init(observer: observer)), context: .init(starManager: catalog, julianDateProvider: date), listViewFactory: ViewFactory { factory.list($0) }))),
            ("05-satellite-list", AnyView(NavigationStack { SatelliteListView(viewModel: .init(state: .init(satelliteInfo: [.brightest100: .loaded(Map([(info.noradIndex, info)]))])), context: .init(category: .brightest100, julianDateRange: range, observer: observer, starManager: catalog, julianDateProvider: date), allPassesViewFactory: ViewFactory { factory.passes($0) }) })),
            ("06-pass-forecast", AnyView(NavigationStack { AllPassesView(viewModel: .init(state: .init(location: CLLocation(latitude: observer.lat, longitude: observer.lon), satelliteTrails: [info.noradIndex: trails])), context: .init(satelliteInfo: info, julianDateRange: range, observer: observer, starManager: catalog, julianDateProvider: date), skyChartFactory: ViewFactory { factory.sky($0) }, passViewFactory: ViewFactory { factory.pass($0) }) })),
            ("07-pass", AnyView(NavigationStack { factory.pass(.init(passIndex: 0, satelliteInfo: info, satelliteCommonName: "ISS (ZARYA)", category: .iss, julianDateRange: range, observer: observer, passSnapshots: pass, starManager: catalog, julianDateProvider: date)) })),
            ("08-detailed-sky", AnyView(DetailedPassView(context: .init(satelliteInfo: info, category: .iss, julianDateRange: range, observer: observer, passSnapshots: pass, starManager: catalog, julianDateProvider: date), skyChartFactory: ViewFactory { factory.sky($0) }))),
            ("09-sky-now", AnyView(RealtimeSkyViewImpl(viewModel: .init(state: .init(observer: observer)), context: .init(basicChartConfigs: .init(), backgroundSkyConfigs: .preset, satelliteMagToRadiusFunction: .default, starManager: catalog, julianDateProvider: { pass.pass.rise.julianDate }), backgroundSkyViewFactory: ViewFactory { factory.background($0) }))),
            ("10-settings", AnyView(NativeSettingsView(session: session))),
            ("11-location", AnyView(NavigationStack { LocationSettingsView(state: .init(currentLocation: CLLocation(latitude: observer.lat, longitude: observer.lon)), selectLocation: { _ in }) })),
            ("12-alarms", AnyView(NavigationStack { AlarmSettingsView(notifications: [], deleteNotifications: { _ in }) })),
            ("13-pass-alarm", AnyView(PassAlarmSettingsModalView(viewModel: .init(), context: .init(satelliteName: "ISS (ZARYA)", category: .iss, passSnapshots: pass, observer: observer)))),
            ("14-ephemerides", AnyView(NavigationStack { EphemeridesManagementView() })),
            ("15-star-detail", AnyView(NavigationStack { SelectedStarLabel(starManager: catalog, star: catalog.brightestStars()[0]).padding().navigationTitle("Star details") })),
            ("17-mission-control", AnyView(MissionControlView(satelliteInfo: info, julianDateProvider: date, julianDateOffset: 0, userLocation: CLLocation(latitude: observer.lat, longitude: observer.lon)))),
            ("18-ephemeris-text", AnyView(NavigationStack { EphemerideTextBrowserView(resource: textResource) })),
            ("19-pass-tutorial", AnyView(AllPassesOnboardingView(onComplete: {}, skyChartFactory: ViewFactory { factory.sky($0) }, satelliteData: SatelliteData(satelliteInfo: info, observer: observer, selectedPass: pass)))),
            ("20-debug", AnyView(DebugMenu(viewModel: .init(state: DebugMenuState(trueJulianDate: now.julianDate, config: .init(), pendingNotifications: [], deliveredNotifications: [], fcmToken: nil))))),
            ("16-night-mode", AnyView(NativeSettingsView(session: session).overlay(Color.red.blendMode(.plusDarker).allowsHitTesting(false)))),
        ]
    }
}

private struct StoreOverview: SatelliteOverviewView { let content: AnyView; var body: some View { content } }

extension Fixture {
    func storeScreens(tianhePasses: [PassSnapshots], featured: Fixture) -> [(String, AnyView)] {
        func next(_ passes: [PassSnapshots]) -> NextPass {
            let visible = passes.first { $0.pass.visibility == .visible }
            let prominent = passes.first { $0.pass.visibility == .visible && ($0.pass.highestIlluminated?.elev ?? 0) > 40 }
            return NextPass(nextVisiblePass: visible?.pass, nextProminentPass: prominent?.pass)
        }
        let date = { now.julianDate }
        let forecast = ForecastModel(client: .init(load: { _, _ in [] }, now: { now }), issNextPass: .loaded(next(passes)), tianheNextPass: .loaded(next(tianhePasses)))
        let overview = AnyView(SatelliteOverviewViewImpl(model: forecast,
            input: .init(observer: observer, authorizationStatus: .authorizedWhenInUse), navigationPath: .constant(NavigationPath()),
            context: .init(starManager: catalog, julianDateProvider: date), singleSatelliteWrappingViewFactory: { factory.detail($0) }))
        let info = featured.info
        let trails = featured.trails
        let passes = featured.passes
        let category: SatelliteCategory = info.noradIndex == 25544 ? .iss : .tianhe
        let passList = AnyView(NavigationStack {
            Color.clear.navigationDestination(isPresented: .constant(true)) {
                AllPassesView(viewModel: .init(state: .init(location: CLLocation(latitude: observer.lat, longitude: observer.lon), satelliteCategory: category, satelliteTrails: [info.noradIndex: trails])),
                    context: .init(satelliteInfo: info, julianDateRange: range, observer: observer, starManager: catalog, julianDateProvider: date),
                    skyChartFactory: ViewFactory { factory.sky($0) }, passViewFactory: ViewFactory { factory.pass($0) })
            }
        })
        let pass = passes.first { $0.pass.visibility == .visible } ?? passes[0]
        // Match the existing north-up chart screenshot with compass tracking off.
        let passView = factory.pass(.init(passIndex: 0, satelliteInfo: info,
            satelliteCommonName: info.noradIndex == 25544 ? "ISS (ZARYA)" : "CSS (TIANHE)", category: category,
            julianDateRange: range, observer: observer, passSnapshots: pass, starManager: catalog, julianDateProvider: date), isCompassEnabled: false)
        let detail = AnyView(NavigationStack {
            Color.clear.navigationDestination(isPresented: .constant(true)) {
                passView
            }
        })
        func root(_ content: AnyView, tab: SatelliteForecast.Tab = .forecast) -> AnyView {
            session.settings.showExperimentalSkyNow = false
            return AnyView(RootView(selectedTab: .constant(tab), settings: session.settings,
                context: .init(starManager: catalog, julianDateProvider: date),
                realtimeSkyViewFactory: { RealtimeSkyViewImpl(viewModel: .init(state: .init(observer: observer)), context: $0, backgroundSkyViewFactory: ViewFactory { factory.background($0) }) },
                satelliteOverviewViewFactory: { _ in StoreOverview(content: content) },
                satelliteCategoryViewFactory: { SatelliteCategoryViewImpl(viewModel: .init(state: .init(observer: observer)), context: $0, listViewFactory: ViewFactory { factory.list($0) }) },
                settingsOverviewFactory: { NativeSettingsView(session: session) }))
        }
        return [("01-forecast", root(overview)), ("02-pass-chart", root(detail)), ("03-pass-list", root(passList)), ("04-satellites", root(overview, tab: .satellites))]
    }
}

private final class StoreHostingController: UIHostingController<AnyView> {
    override var prefersStatusBarHidden: Bool { false }
    override var preferredStatusBarStyle: UIStatusBarStyle { .lightContent }
}
