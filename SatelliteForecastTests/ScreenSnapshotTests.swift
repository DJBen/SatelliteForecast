import XCTest
import SwiftUI
import CoreLocation
import CoreMotion
import BTree
@testable import SatelliteForecastApp
import SatelliteForecast
@testable import SatelliteForecastImpl
import SatelliteKit
import SolarSystem

/// Native view snapshots at a fixed phone size, locale, timezone and orbital epoch.
/// No live store middleware, location permissions, notifications or network loaders.
@MainActor
final class ScreenSnapshotTests: XCTestCase {
    private let isSEReview = ProcessInfo.processInfo.environment["SNAPSHOT_DEVICE"] == "se3"
    private var size: CGSize { isSEReview ? CGSize(width: 375, height: 667) : CGSize(width: 402, height: 874) }
    private let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()

    /// Opt-in interactive fixture for native navigation gestures (driven by the simulator CLI).
    /// Create /tmp/satellite-pass-navigation-review before running this test; remove it to finish.
    func testInteractivePassNavigation() async throws {
        let marker = "/tmp/satellite-pass-navigation-review"
        guard FileManager.default.fileExists(atPath: marker) else {
            throw XCTSkip("Interactive navigation review was not requested")
        }
        UserDefaults.standard.set(true, forKey: "hasCompletedAllPassesOnboarding")
        UserDefaults.standard.set(false, forKey: "passCompassEnabled")
        let fixture = try Fixture(catalog: await AppStarCatalog.load())
        let invisible = fixture.passes.filter { $0.pass.visibility != .visible }
        XCTAssertGreaterThan(invisible.count, 2)
        let trails = SatelliteTrails(observer: fixture.observer, snapshots: fixture.trails.snapshots,
            passSnapshots: Array(invisible.prefix(4)))
        let navigation = PassNavigationReviewState()
        let path = Binding(get: { navigation.path }, set: { navigation.path = $0 })
        let view = NavigationStack(path: path) {
            AllPassesView(viewModel: .init(state: .init(location: CLLocation(latitude: fixture.observer.lat, longitude: fixture.observer.lon),
                satelliteTrails: [fixture.info.noradIndex: trails])),
                context: .init(satelliteInfo: fixture.info, julianDateRange: fixture.range,
                    observer: fixture.observer, starManager: fixture.catalog, julianDateProvider: { fixture.now.julianDate }),
                skyChartFactory: ViewFactory { fixture.factory.sky($0) }, passViewFactory: ViewFactory { fixture.factory.pass($0) })
        }
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.first as? UIWindowScene)
        let window = UIWindow(windowScene: scene)
        window.overrideUserInterfaceStyle = .dark
        let host = UIHostingController(rootView: view.environment(\.passNavigationPath, path).environment(\.colorScheme, .dark).environment(\.motionManagerKey, CMMotionManager()))
        window.rootViewController = host
        window.makeKeyAndVisible()
        defer { window.isHidden = true; window.rootViewController = nil }
        try "ready".write(toFile: marker + "-ready", atomically: true, encoding: .utf8)
        for _ in 0..<1500 {
            if !FileManager.default.fileExists(atPath: marker) {
                XCTAssertEqual(navigation.path.count, 0, "Back navigation must restore the list without leftover destinations")
                return
            }
            try await Task.sleep(for: .milliseconds(200))
        }
        XCTFail("Interactive review timed out")
    }

    func testPointSourceRenderingReview() async throws {
        let mapping = BackgroundSkyConfigs.StarMagToDisplayRadiusMappingFunction.self
        for scale: CGFloat in [0.75, 1, 1.35] {
            let radii = stride(from: -30.0, through: 30.0, by: 0.1).map {
                mapping.pointSourceRadius(magnitude: $0, scale: scale)
            }
            XCTAssertTrue(radii.allSatisfy { $0.isFinite && $0 >= 0.55 * scale && $0 <= 3.2 * scale })
            XCTAssertTrue(zip(radii, radii.dropFirst()).allSatisfy { $0 >= $1 })
        }
        let catalog = try await AppStarCatalog.load()
        let fixture = try Fixture(catalog: catalog)
        let cases: [(String, String, LatLonAlt, Double, Bool)] = [
            ("2020-venus-dusk", "2020-04-28T00:00:00Z", LatLonAlt(37.49, -122.23, 0), -9, false),
            ("2023-venus-dawn", "2023-09-19T00:00:00Z", LatLonAlt(37.49, -122.23, 0), -9, true),
            ("2025-winter-night", "2025-01-10T00:00:00Z", LatLonAlt(51.51, -0.13, 0), -30, false),
            ("2026-venus-dusk", "2026-09-16T00:00:00Z", LatLonAlt(37.49, -122.23, 0), -7, false),
            ("2028-southern-night", "2028-07-10T00:00:00Z", LatLonAlt(-33.87, 151.21, 0), -35, false)
        ]
        var report = "Date-based rendering review (UTC; observer degrees)\n"
        for (name, iso, observer, elevation, morning) in cases {
            let start = try XCTUnwrap(ISO8601DateFormatter().date(from: iso)).julianDate
            let candidates = (0..<1440).map { start + Double($0) / 1440 }.filter {
                (SkyChartAtmosphere.sun(observer: observer, julianDate: $0).azim < 180) == morning
            }
            let date = try XCTUnwrap(candidates.min {
                abs(SkyChartAtmosphere.sun(observer: observer, julianDate: $0).elev - elevation) <
                abs(SkyChartAtmosphere.sun(observer: observer, julianDate: $1).elev - elevation)
            })
            let venus = azel(time: Date(julianDate: date), site: LatLon(observer), cele: RADec(SolarSystemBody.venus.eci(julianDay: date)))
            if name.contains("venus") { XCTAssertGreaterThan(venus.elev, 0) }
            report += "\(name): \(ISO8601DateFormatter().string(from: Date(julianDate: date))), observer \(observer), Sun \(SkyChartAtmosphere.sun(observer: observer, julianDate: date).elev), Venus altitude \(venus.elev), magnitude \(SolarSystemBody.venus.apparentMagnitude(julianDay: date) ?? 0)\n"
            for (configuration, configs) in [("standard", BackgroundSkyConfigs.preset),
                ("compact", SkyChartConfigs.preview.backgroundSkyConfigs),
                ("dense", BackgroundSkyConfigs(stars: .limitedMagnitude(6),
                    starMagToDisplayRadiusMappingFunction: .init(id: "review-detail") {
                        mapping.pointSourceRadius(magnitude: $0, scale: 1.35)
                    }))] {
                let view = RealtimeSkyViewImpl(viewModel: .init(state: .init(observer: observer)),
                    context: .init(basicChartConfigs: .init(), backgroundSkyConfigs: configs,
                        satelliteMagToRadiusFunction: .default, starManager: catalog, julianDateProvider: { date }),
                    backgroundSkyViewFactory: ViewFactory { fixture.factory.background($0) })
                try await assertSnapshot(AnyView(view
                    .frame(width: configuration == "compact" ? 210 : 338)
                    .frame(maxWidth: .infinity)), name: "point-source-\(name)-\(configuration)-dark", style: .dark)
            }
        }
        let detail = try XCTUnwrap(fixture.screens().first { $0.0 == "08-detailed-sky" }?.1)
        try await assertSnapshot(detail, name: "point-source-2021-detailed-pass-dark", style: .dark)
        let folder = root.appendingPathComponent("Documentation/DesignReview/PointSources")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try report.write(to: folder.appendingPathComponent("moments.txt"), atomically: true, encoding: .utf8)
    }

    func testGeographicLocalizationGallery() async throws {
        let lookup = GeographicRegionLookup()
        let landResult = await lookup.summary(latitude: 34.05, longitude: -118.24)
        let oceanResult = await lookup.summary(latitude: 0, longitude: -140)
        let land = try XCTUnwrap(landResult)
        let ocean = try XCTUnwrap(oceanResult)
        // Presentation fixture: exercise all names and nearby-country grammar together.
        let nearby = GeographicRegionLookup.Summary(place: ocean.place, isWater: true,
            nearestLand: land.place, distanceKilometers: 200, bearingDegrees: 90)
        for style in [UIUserInterfaceStyle.dark] {
            let view = VStack(alignment: .leading, spacing: 12) {
                ForEach(["en", "fr", "es", "pt-BR", "ru", "ja", "ko", "zh-Hans"], id: \.self) { language in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(language).font(.caption.bold()).foregroundStyle(.primary)
                        GeographicLocationCaption(summary: land)
                        GeographicLocationCaption(summary: nearby)
                        GeographicLocationCaption(summary: nil)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .environment(\.locale, Locale(identifier: language))
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(AppTheme.background)
            try await assertSnapshot(AnyView(view), name: "geography-localization-\(style == .dark ? "dark" : "light")", style: style)
        }
    }

    func testPassListLayoutReview() async throws {
        UserDefaults.standard.set(true, forKey: "hasCompletedAllPassesOnboarding")
        NSTimeZone.default = TimeZone(secondsFromGMT: 0)!
        let fixture = try Fixture(catalog: await AppStarCatalog.load())
        let view = try XCTUnwrap(fixture.screens().first { $0.0 == "06-pass-forecast" }?.1)
        let visibleCount = fixture.passes.filter { $0.pass.visibility == .visible }.count
        for style in [UIUserInterfaceStyle.dark] {
            let appearance = style == .dark ? "dark" : "light"
            try await assertSnapshot(view, name: "06-pass-forecast-\(appearance)", style: style)
            try await assertSnapshot(view, name: "pass-list-visible-\(appearance)", style: style,
                scrollDistance: 180, checkFullHeight: false)
            try await assertSnapshot(view, name: "pass-list-invisible-\(appearance)", style: style,
                scrollDistance: CGFloat(visibleCount) * (isSEReview ? 192 : 224.5) + 510, checkFullHeight: false)
        }
    }

    func testHomeDiscovery() async throws {
        let defaults = UserDefaults.standard
        let previous = defaults.object(forKey: "hasCompletedHomeOnboarding")
        defer { defaults.set(previous, forKey: "hasCompletedHomeOnboarding") }
        defaults.set(false, forKey: "hasCompletedHomeOnboarding")
        let fixture = try Fixture(catalog: await AppStarCatalog.load())
        let home = try XCTUnwrap(fixture.screens().first { $0.0 == "03-forecast" }?.1)
        for language in ["en", "zh-Hans"] {
            try await assertSnapshot(AnyView(home.environment(\.locale, Locale(identifier: language))),
                name: "home-discovery-\(language)-dark", style: .dark)
        }
        XCTAssertFalse(defaults.bool(forKey: "hasCompletedHomeOnboarding"))
        for language in ["zh", "zh-Hans", "zh-Hant", "zh-TW", "zh-HK"] {
            XCTAssertEqual(SatelliteOverviewViewImpl.stationOrder(for: Locale(identifier: language)), [.tianhe, .iss])
        }
        for language in ["en", "fr", "ja", "ko", "ru", "es", "pt-BR"] {
            XCTAssertEqual(SatelliteOverviewViewImpl.stationOrder(for: Locale(identifier: language)), [.iss, .tianhe])
        }
        defaults.set(true, forKey: "hasCompletedHomeOnboarding")
        DebugModel().send(.resetHomeOnboarding)
        XCTAssertFalse(defaults.bool(forKey: "hasCompletedHomeOnboarding"))
    }

    func testPassDiscoveryGlow() async throws {
        let defaults = UserDefaults.standard
        let previous = defaults.object(forKey: "hasCompletedAllPassesOnboarding")
        defer { defaults.set(previous, forKey: "hasCompletedAllPassesOnboarding") }
        defaults.set(false, forKey: "hasCompletedAllPassesOnboarding")
        let fixture = try Fixture(catalog: await AppStarCatalog.load())
        let view = try XCTUnwrap(fixture.screens().first { $0.0 == "06-pass-forecast" }?.1)
        try await assertSnapshot(view, name: "pass-discovery-glow-dark", style: .dark,
            scrollDistance: 180, checkFullHeight: false)
        XCTAssertFalse(defaults.bool(forKey: "hasCompletedAllPassesOnboarding"),
            "Viewing the list must not consume the first visible-pass tutorial")
    }

    func testFirstVisiblePassVideo() async throws {
        let defaults = UserDefaults.standard
        let previous = defaults.object(forKey: "hasCompletedAllPassesOnboarding")
        defer { defaults.set(previous, forKey: "hasCompletedAllPassesOnboarding") }
        defaults.set(false, forKey: "hasCompletedAllPassesOnboarding")
        let fixture = try Fixture(catalog: await AppStarCatalog.load())
        let detail = try XCTUnwrap(fixture.screens().first { $0.0 == "07-pass-compass-off" }?.1)
        try await assertSnapshot(AnyView(detail.modifier(FirstVisiblePassTutorial(isVisible: false))),
            name: "tutorial-invisible-pass-dark", style: .dark, expectedModal: false)
        XCTAssertFalse(defaults.bool(forKey: "hasCompletedAllPassesOnboarding"))
        try await assertSnapshot(AnyView(detail.modifier(FirstVisiblePassTutorial(isVisible: true))),
            name: "tutorial-first-visible-pass-dark", style: .dark, expectedModal: true)
        XCTAssertTrue(defaults.bool(forKey: "hasCompletedAllPassesOnboarding"))
        try await assertSnapshot(AnyView(detail.modifier(FirstVisiblePassTutorial(isVisible: true))),
            name: "tutorial-returning-visible-pass-dark", style: .dark, expectedModal: false)
    }

    func testRecordedOnboardingPass() throws {
        let example = try OnboardingPassExample.load()
        XCTAssertEqual(example.pass.pass.highestIlluminated?.elev ?? 0, 55.6, accuracy: 1)
        XCTAssertEqual(example.pass.pass.rise.julianDate,
                       Date(timeIntervalSince1970: 1789011297).julianDate, accuracy: 3.0 / 86400)
        XCTAssertTrue(example.samples.contains { $0.isIlluminated })
        XCTAssertTrue(example.samples.contains { !$0.isIlluminated })
        XCTAssertGreaterThan(example.samples.count, 300)
    }

    func testAllScreensLightAndDark() async throws {
        UserDefaults.standard.set(true, forKey: "hasCompletedAllPassesOnboarding")
        NSTimeZone.default = TimeZone(secondsFromGMT: 0)!
        UIView.setAnimationsEnabled(false)
        defer { UIView.setAnimationsEnabled(true) }
        let catalog = try await AppStarCatalog.load()
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("snapshot-empty-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        for style in [UIUserInterfaceStyle.dark] {
            let fixture = try Fixture(catalog: catalog)
            for (name, view) in fixture.screens() {
                let selected = ProcessInfo.processInfo.environment["SNAPSHOT_SCREEN"] ?? ""
                if !selected.isEmpty && !selected.split(separator: ",").contains(where: { name.hasPrefix($0) }) { continue }
                try await assertSnapshot(AnyView(view.environment(\.ephemerisDirectory, directory)), name: "\(name)-\(style == .dark ? "dark" : "light")", style: style)
            }
        }
    }

    /// Full native sky views at solar-elevation fixtures in both appearances.
    func testAtmosphereScreens() async throws {
        let catalog = try await AppStarCatalog.load()
        let fixture = try Fixture(catalog: catalog)
        let times = (0..<1440).map { fixture.now.julianDate + Double($0) / 1440 }
        for (name, elevation, morning) in [("dawn", -3.0, true), ("dusk", -3.0, false),
                                            ("sunset", 2.0, false), ("daylight", 30.0, false), ("night", -25.0, false)] {
            let candidates = times.filter {
                (SkyChartAtmosphere.sun(observer: fixture.observer, julianDate: $0).azim < 180) == morning
            }
            let date = try XCTUnwrap(candidates.min {
                abs(SkyChartAtmosphere.sun(observer: fixture.observer, julianDate: $0).elev - elevation) <
                abs(SkyChartAtmosphere.sun(observer: fixture.observer, julianDate: $1).elev - elevation)
            })
            let sun = SkyChartAtmosphere.sun(observer: fixture.observer, julianDate: date)
            XCTAssertLessThan(abs(sun.elev - elevation), 0.3)
            for style in [UIUserInterfaceStyle.dark, .light] {
                let view = RealtimeSkyViewImpl(viewModel: .init(state: .init(observer: fixture.observer)),
                    context: .init(basicChartConfigs: .init(), backgroundSkyConfigs: .preset,
                        satelliteMagToRadiusFunction: .default, starManager: catalog, julianDateProvider: { date }),
                    backgroundSkyViewFactory: ViewFactory { fixture.factory.background($0) })
                try await assertSnapshot(AnyView(view), name: "atmosphere-\(name)-\(style == .dark ? "dark" : "light")", style: style)
            }
        }
    }

    func testAtmospherePassPath() async throws {
        let catalog = try await AppStarCatalog.load()
        let fixture = try Fixture(catalog: catalog)
        let pass = try XCTUnwrap(fixture.passes.max {
            $0.pass.sunElevationAtTransit < $1.pass.sunElevationAtTransit
        })
        for style in [UIUserInterfaceStyle.dark, .light] {
            let view = NavigationStack {
                fixture.factory.pass(.init(passIndex: 0, satelliteInfo: fixture.info,
                    satelliteCommonName: "ISS (ZARYA)", category: .iss, julianDateRange: fixture.range,
                    observer: fixture.observer, passSnapshots: pass, starManager: catalog,
                    julianDateProvider: { fixture.now.julianDate }))
            }
            try await assertSnapshot(AnyView(view), name: "atmosphere-pass-\(style == .dark ? "dark" : "light")", style: style)
        }
    }

    func testDaytimeMoonScreens() async throws {
        let catalog = try await AppStarCatalog.load()
        let fixture = try Fixture(catalog: catalog)
        let start = ISO8601DateFormatter().date(from: "2024-04-16T00:00:00Z")!.julianDate
        let dates = (0..<96).map { start + Double($0) / 96 }
        let time = try XCTUnwrap(dates.first {
            let moon = MoonAppearance.Geometry(julianDate: $0, observer: fixture.observer)
            return moon.sunElevation > 25 && moon.coordinate.elev > 30 && moon.illuminatedFraction > 0.4
        })
        for style in [UIUserInterfaceStyle.dark, .light] {
            let view = RealtimeSkyViewImpl(viewModel: .init(state: .init(observer: fixture.observer)),
                context: .init(basicChartConfigs: .init(), backgroundSkyConfigs: .preset,
                    satelliteMagToRadiusFunction: .default, starManager: catalog, julianDateProvider: { time }),
                backgroundSkyViewFactory: ViewFactory { fixture.factory.background($0) })
            try await assertSnapshot(AnyView(view), name: "moon-daytime-\(style == .dark ? "dark" : "light")", style: style)
        }
    }

    func testFloatingTabScreens() async throws {
        let catalog = try await AppStarCatalog.load()
        let fixture = try Fixture(catalog: catalog)
        for (name, view) in fixture.storeScreens(tianhePasses: fixture.passes, featured: fixture)
            where ["01-forecast", "03-pass-list", "04-satellites"].contains(name) {
            try await assertSnapshot(view, name: "tabs-\(name)-scrolled", style: .dark, scrollDistance: 180)
        }
    }

    func testMoonPhaseScreens() async throws {
        let dates = [("Crescent · Earthshine", "2024-04-11T04:00:00Z"),
                     ("First quarter", "2024-04-16T04:00:00Z"),
                     ("Full Moon", "2024-04-24T04:00:00Z"),
                     ("Waning crescent", "2024-05-05T12:00:00Z")]
        let observer = LatLonAlt(37.49, -122.23, 0)
        let images = try dates.map { name, date in
            let jd = ISO8601DateFormatter().date(from: date)!.julianDate
            let geometry = MoonAppearance.Geometry(julianDate: jd, observer: observer)
            return (name, try XCTUnwrap(MoonAppearance.image(geometry: geometry)), geometry.illuminatedFraction, try XCTUnwrap(MoonAppearance.photograph(geometry: geometry)))
        }
        let gallery = VStack(alignment: .leading, spacing: 12) {
            Text("The Moon in your sky").font(.title2.bold())
            Text("Surface detail · phase · Earthshine").font(.subheadline).foregroundStyle(.secondary)
            ForEach(images.indices, id: \.self) { index in
                HStack(spacing: 24) {
                    Image(uiImage: images[index].1).resizable().frame(width: 96, height: 96)
                    VStack(alignment: .leading, spacing: 8) {
                        Text(images[index].0).font(.headline)
                        Text("\(Int(images[index].2 * 100))% illuminated").font(.caption).foregroundStyle(.secondary)
                        HStack {
                            Image(uiImage: images[index].3).resizable().frame(width: 72, height: 72).frame(width: 24, height: 24)
                            Text("Chart glow").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }
            Text("Angles follow the north-up sky chart.\nTexture: NASA’s Scientific Visualization Studio.")
                .font(.caption).foregroundStyle(.secondary)
        }.padding(24).frame(maxWidth: .infinity, maxHeight: .infinity).background(Color.black)
        try await assertSnapshot(AnyView(gallery), name: "moon-phases-dark", style: .dark)
        let catalog = try await AppStarCatalog.load()
        let fixture = try Fixture(catalog: catalog)
        for (name, date) in [("moon-chart", dates[0].1), ("moon-chart-full", dates[2].1)] {
            let time = ISO8601DateFormatter().date(from: date)!.julianDate
            for style in [UIUserInterfaceStyle.dark, .light] {
                let view = RealtimeSkyViewImpl(viewModel: .init(state: .init(observer: observer)),
                    context: .init(basicChartConfigs: .init(), backgroundSkyConfigs: .preset,
                        satelliteMagToRadiusFunction: .default, starManager: catalog, julianDateProvider: { time }),
                    backgroundSkyViewFactory: ViewFactory { fixture.factory.background($0) })
                try await assertSnapshot(AnyView(view), name: "\(name)-\(style == .dark ? "dark" : "light")", style: style)
            }
        }
    }

    /// Full-resolution store captures are separate from regression baselines.
    func testAppStoreScreenshots() async throws {
        let env = ProcessInfo.processInfo.environment
        guard let destination = env["STORE_SCREENSHOT_OUTPUT"] else { throw XCTSkip("Run scripts/capture-store-screenshots.py") }
        let locale = env["STORE_SCREENSHOT_LOCALE"] ?? "en-US"
        let previousTimeZone = NSTimeZone.default
        let locations: [String: (String, Double, Double, String)] = [
            "en-US": ("US", 37.486743, -122.226560, "America/Los_Angeles"),
            "fr-FR": ("FR", 45.764, 4.8357, "Europe/Paris"),
            "es-ES": ("ES", 40.4168, -3.7038, "Europe/Madrid"),
            "pt-BR": ("BR", -23.5505, -46.6333, "America/Sao_Paulo"),
            "ru": ("RU", 48.708, 44.5133, "Europe/Volgograd"),
            "ja": ("JP", 35.6762, 139.6503, "Asia/Tokyo"),
            "ko": ("KR", 37.5665, 126.978, "Asia/Seoul"),
            "zh-Hans": ("CN", 31.2304, 121.4737, "Asia/Shanghai")
        ]
        let location = try XCTUnwrap(locations[locale])
        let timeZone = TimeZone(identifier: location.3)!
        NSTimeZone.default = timeZone
        defer { NSTimeZone.default = previousTimeZone }
        UserDefaults.standard.set(true, forKey: "hasCompletedHomeOnboarding")
        UserDefaults.standard.set(true, forKey: "hasCompletedAllPassesOnboarding")
        UIView.setAnimationsEnabled(false)
        defer { UIView.setAnimationsEnabled(true) }
        let catalog = try await AppStarCatalog.load()
        let fixtureURL = root.appendingPathComponent("SatelliteForecastTests/Fixtures/AppStore")
        func tle(_ name: String) throws -> [String] {
            try String(contentsOf: fixtureURL.appendingPathComponent(name), encoding: .utf8)
                .split(whereSeparator: \.isNewline).map(String.init)
        }
        let issTLE = try tle("iss.tle")
        let tianheTLE = try tle("tiangong.tle")
        let selectedTLE = locale == "zh-Hans" ? tianheTLE : issTLE
        let satellite = Satellite(withTLE: try Elements(selectedTLE[0], selectedTLE[1], selectedTLE[2]))
        let start = ISO8601DateFormatter().date(from: "2026-09-10T01:00:00Z")!.julianDate
        var candidates: [(Double, Double)] = []
        for offset in stride(from: 0.0, to: 3 * 86400, by: 45) {
            let date = start + offset / 86400
            let point = try satellite.geoPosition(julianDays: date)
            let deltaLongitude = (point.lon - location.2 + 540).truncatingRemainder(dividingBy: 360) - 180
            let distance = pow(point.lat - location.1, 2) + pow(deltaLongitude * cos(location.1 * .pi / 180), 2)
            candidates.append((date, distance))
        }
        var homeDate: Double?
        var geography = ""
        for candidate in candidates.sorted(by: { $0.1 < $1.1 }).prefix(100) {
            let point = try satellite.geoPosition(julianDays: candidate.0)
            if let summary = await GeographicRegionLookup.shared.summary(latitude: point.lat, longitude: point.lon),
               !summary.isWater, summary.place?.countryCode == location.0 {
                homeDate = candidate.0
                geography = summary.compactDescription(locale: Locale(identifier: locale))
                break
            }
        }
        let now = Date(julianDate: try XCTUnwrap(homeDate, "No real overflight found for \(locale)"))
        let observer = LatLonAlt(location.1, location.2, 0)
        let fixture = try Fixture(catalog: catalog, now: now, tle: issTLE, observer: observer)
        let tiangong = try Fixture(catalog: catalog, now: now, tle: tianheTLE, observer: observer)
        var bestPass: PassSnapshots?
        for dayOffset in [0.0, -7.0, 7.0] {
            let search = try Fixture(catalog: catalog, now: Date(julianDate: start + dayOffset),
                tle: selectedTLE, observer: observer)
            for pass in search.passes where pass.pass.visibility == .visible && pass.pass.sunElevationAtTransit < -10 {
                if (pass.pass.highestIlluminated?.elev ?? 0) > (bestPass?.pass.highestIlluminated?.elev ?? 0) {
                    bestPass = pass
                }
            }
            if (bestPass?.pass.highestIlluminated?.elev ?? 0) > 55 { break }
        }
        let best = try XCTUnwrap(bestPass)
        XCTAssertGreaterThan(best.pass.highestIlluminated?.elev ?? 0, 45, "Choose a spectacular dark-sky pass")
        let featured = try Fixture(catalog: catalog,
            now: Date(julianDate: best.pass.rise.julianDate - 1.0 / 24), tle: selectedTLE, observer: observer)
        let report: [String: Any] = ["locale": locale, "country": location.0,
            "homeDateUTC": ISO8601DateFormatter().string(from: now), "geography": geography,
            "observerLatitude": observer.lat, "observerLongitude": observer.lon,
            "timeZone": location.3, "featuredNORAD": featured.info.noradIndex,
            "passForecastDateUTC": ISO8601DateFormatter().string(from: featured.now),
            "featuredPassUTC": ISO8601DateFormatter().string(from: Date(julianDate: best.pass.rise.julianDate)),
            "elevation": best.pass.highestIlluminated?.elev ?? 0]
        try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys])
            .write(to: URL(fileURLWithPath: destination).appendingPathComponent("selection-\(locale).json"))
        let screens = fixture.storeScreens(tianhePasses: tiangong.passes, tianheInfo: tiangong.info, featured: featured)
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
                .environment(\.timeZone, timeZone)
                .environment(\.colorScheme, .dark)
                .environment(\.dynamicTypeSize, .large)
                .transaction { $0.animation = nil })
            host.setNeedsStatusBarAppearanceUpdate()
            host.view.frame = window.bounds
            host.view.layoutIfNeeded()
            // Allow actual MapKit tiles and actor-rendered star charts to finish.
            try await Task.sleep(for: .seconds(name.hasPrefix("02") || name.hasPrefix("03") ? 15 : 4))
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

    private func assertSnapshot(_ view: AnyView, name: String, style: UIUserInterfaceStyle, scrollDistance: CGFloat? = nil, checkFullHeight: Bool = true, expectedModal: Bool? = nil) async throws {
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
        try await Task.sleep(for: .milliseconds((name.hasPrefix("02-predictions-intro") || name.hasPrefix("tutorial-")) ? 2500 : 800))
        host.view.layoutIfNeeded()
        if let scrollDistance {
            func scrollViews(in view: UIView) -> [UIScrollView] {
                (view as? UIScrollView).map { [$0] } ?? view.subviews.flatMap { scrollViews(in: $0) }
            }
            let scroll = try XCTUnwrap(scrollViews(in: host.view).filter {
                !$0.isHidden && $0.bounds.height > 200
            }.max { $0.bounds.height < $1.bounds.height })
            if checkFullHeight {
                XCTAssertGreaterThanOrEqual(scroll.convert(scroll.bounds, to: window).maxY,
                                            window.bounds.maxY - 1, "Scroll viewport should extend behind the tab bar")
            }
            let bottom = scroll.contentSize.height - scroll.bounds.height + scroll.adjustedContentInset.bottom
            scroll.setContentOffset(CGPoint(x: 0, y: max(-scroll.adjustedContentInset.top, min(bottom, scrollDistance))), animated: false)
            try await Task.sleep(for: .milliseconds(500))
            host.view.layoutIfNeeded()
        }
        if let expectedModal {
            XCTAssertEqual(host.presentedViewController != nil, expectedModal,
                "Only the first visible pass should present the tutorial video")
        }
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let image = UIGraphicsImageRenderer(size: size, format: format).image { _ in
            if expectedModal == true {
                window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
            } else {
                host.view.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
            }
        }
        window.isHidden = true
        window.rootViewController = nil
        let attachment = XCTAttachment(image: image)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
        let mode = ProcessInfo.processInfo.environment["SNAPSHOT_RECORD"] ?? ""
        let baseFolder = root.appendingPathComponent(name.hasPrefix("point-source-") ? "Documentation/DesignReview/PointSources" : "Documentation/DesignReview/\(mode == "before" ? "before" : "after")")
        let folder = isSEReview ? baseFolder.appendingPathComponent("se3") : baseFolder
        let url = folder.appendingPathComponent(name + ".png")
        let data = try XCTUnwrap(image.pngData())
        // Playback timing is intentionally live. Assert modal presentation above,
        // and keep a review capture instead of pixel-comparing video frames.
        if expectedModal == true, mode != "before", mode != "after" { return }
        if mode == "before" || mode == "after" || name.hasPrefix("point-source-") {
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
    let observer: LatLonAlt
    let info: SatelliteInfo
    let passes: [PassSnapshots]
    let textResource: EphemerideResource
    let session: AppSession
    let trails: SatelliteTrails
    var factory: ScreenFactory { ScreenFactory(session: session) }
    var range: ClosedRange<Double> { now.julianDate...(now.julianDate + 7) }

    init(catalog: AppStarCatalog, now: Date = Date(timeIntervalSince1970: 1622592000), tle: [String]? = nil, observer: LatLonAlt = LatLonAlt(37.486743, -122.226560, 0)) throws {
        self.observer = observer
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
        let forecast = ForecastModel(client: .init(load: { _, _ in [] },
                                     satelliteInfo: { satellite in satellite == .iss ? self.info : nil }, now: { now }),
                                     issNextPass: .loaded(nextPass), tianheNextPass: .loaded(nextPass))
        let overview = SatelliteOverviewViewImpl(model: forecast,
            input: .init(observer: observer, authorizationStatus: .authorizedWhenInUse),
            navigationPath: .constant(NavigationPath()),
            context: .init(starManager: catalog, julianDateProvider: date),
            singleSatelliteWrappingViewFactory: { factory.detail($0) })
        return [
            ("01-welcome", AnyView(OnboardingView(session: session, onComplete: {}))),
            ("02-predictions-intro", AnyView(OnboardingView(session: session, initialPage: 1, onComplete: {}))),
            ("03-forecast", AnyView(overview)),
            ("04-satellites", AnyView(SatelliteCategoryViewImpl(viewModel: .init(state: .init(observer: observer)), context: .init(starManager: catalog, julianDateProvider: date), listViewFactory: ViewFactory { factory.list($0) }))),
            ("05-satellite-list", AnyView(NavigationStack { SatelliteListView(viewModel: .init(state: .init(satelliteInfo: [.brightest100: .loaded(Map([(info.noradIndex, info)]))])), context: .init(category: .brightest100, julianDateRange: range, observer: observer, starManager: catalog, julianDateProvider: date), allPassesViewFactory: ViewFactory { factory.passes($0) }) })),
            ("06-pass-forecast", AnyView(NavigationStack { AllPassesView(viewModel: .init(state: .init(location: CLLocation(latitude: observer.lat, longitude: observer.lon), satelliteTrails: [info.noradIndex: trails])), context: .init(satelliteInfo: info, julianDateRange: range, observer: observer, starManager: catalog, julianDateProvider: date), skyChartFactory: ViewFactory { factory.sky($0) }, passViewFactory: ViewFactory { factory.pass($0) }) })),
            ("07-pass", AnyView(NavigationStack { factory.pass(.init(passIndex: 0, satelliteInfo: info, satelliteCommonName: "ISS (ZARYA)", category: .iss, julianDateRange: range, observer: observer, passSnapshots: pass, starManager: catalog, julianDateProvider: date)) })),
            ("07-pass-compass-off", AnyView(NavigationStack { factory.pass(.init(passIndex: 0, satelliteInfo: info, satelliteCommonName: "ISS (ZARYA)", category: .iss, julianDateRange: range, observer: observer, passSnapshots: pass, starManager: catalog, julianDateProvider: date), isCompassEnabled: false) })),
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
            ("20-debug", AnyView(DebugMenu(viewModel: .init(state: DebugMenuState(trueJulianDate: now.julianDate, config: .init(), pendingNotifications: [], deliveredNotifications: [], fcmToken: nil))))),
            ("16-night-mode", AnyView(NativeSettingsView(session: session).overlay(Color.red.blendMode(.plusDarker).allowsHitTesting(false)))),
        ]
    }
}

private struct StoreOverview: SatelliteOverviewView { let content: AnyView; var body: some View { content } }

extension Fixture {
    func storeScreens(tianhePasses: [PassSnapshots], tianheInfo: SatelliteInfo? = nil, featured: Fixture) -> [(String, AnyView)] {
        func next(_ passes: [PassSnapshots]) -> NextPass {
            let visible = passes.first { $0.pass.visibility == .visible }
            let prominent = passes.first { $0.pass.visibility == .visible && ($0.pass.highestIlluminated?.elev ?? 0) > 45 }
            return NextPass(nextVisiblePass: visible?.pass, nextProminentPass: prominent?.pass)
        }
        let date = { now.julianDate }
        let forecast = ForecastModel(client: .init(load: { _, _ in [] },
                                     satelliteInfo: { satellite in satellite == .iss ? self.info : tianheInfo }, now: { now }), issNextPass: .loaded(next(passes)), tianheNextPass: .loaded(next(tianhePasses)))
        let overview = AnyView(SatelliteOverviewViewImpl(model: forecast,
            input: .init(observer: observer, authorizationStatus: .authorizedWhenInUse), navigationPath: .constant(NavigationPath()),
            context: .init(starManager: catalog, julianDateProvider: date), singleSatelliteWrappingViewFactory: { factory.detail($0) }))
        let passObserver = featured.observer
        let passRange = featured.range
        let passDate = { featured.now.julianDate }
        let info = featured.info
        let trails = featured.trails
        let passes = featured.passes
        let category: SatelliteCategory = info.noradIndex == 25544 ? .iss : .tianhe
        let passList = AnyView(NavigationStack {
            Color.clear.navigationDestination(isPresented: .constant(true)) {
                AllPassesView(viewModel: .init(state: .init(location: CLLocation(latitude: passObserver.lat, longitude: passObserver.lon), satelliteCategory: category, satelliteTrails: [info.noradIndex: trails])),
                    context: .init(satelliteInfo: info, julianDateRange: passRange, observer: passObserver, starManager: catalog, julianDateProvider: passDate),
                    skyChartFactory: ViewFactory { factory.sky($0) }, passViewFactory: ViewFactory { factory.pass($0) })
            }
        })
        // Feature the strongest genuinely illuminated arc in the forecast window.
        let pass = passes.first { $0.pass.visibility == .visible && $0.pass.sunElevationAtTransit < -10 } ?? passes[0]
        // Match the existing north-up chart screenshot with compass tracking off.
        let passView = factory.pass(.init(passIndex: 0, satelliteInfo: info,
            satelliteCommonName: info.noradIndex == 25544 ? "ISS (ZARYA)" : "CSS (TIANHE)", category: category,
            julianDateRange: passRange, observer: passObserver, passSnapshots: pass, starManager: catalog, julianDateProvider: passDate), isCompassEnabled: false)
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

@MainActor @Observable
private final class PassNavigationReviewState {
    var path = NavigationPath()
}
