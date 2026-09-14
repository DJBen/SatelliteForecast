import XCTest
import UIKit
import BTree
import SatelliteForecast
import SatelliteKit
@testable import SatelliteForecastImpl

@MainActor
final class ForecastTests: XCTestCase {
    private let date = Date(timeIntervalSince1970: 1_622_592_000)
    private let observer = LatLonAlt(37, -122, 0)

    private func pass(at date: Date, id: UInt = 25544) -> Pass {
        let jd = date.julianDate
        return Pass(noradIndex: id, rise: .init(julianDate: jd, azim: 0, elev: 0),
            set: .init(julianDate: jd + 0.01, azim: 180, elev: 0),
            culmination: .init(julianDate: jd + 0.005, azim: 90, elev: 60),
            illumination: .init(initiallyIlluminated: true, changes: []), sunElevationAtTransit: -20)
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
        let info = try SatelliteInfo(elements: Elements(lines[0], lines[1], lines[2]))
        let task = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            return try info.generateSnapshots(observer: observer, julianDateRange: date.julianDate...(date.julianDate + 7))
        }
        do { _ = try await task.value; XCTFail("Expected cancelled prediction") }
        catch is CancellationError { }
    }

    func testPassListRejectsSupersededObserver() async throws {
        let lines = String(decoding: tle, as: UTF8.self).split(separator: "\n").map(String.init)
        let info = try SatelliteInfo(elements: Elements(lines[0], lines[1], lines[2]))
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
        let info = try SatelliteInfo(elements: Elements(lines[0], lines[1], lines[2]))
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
        let fixture = try Fixture(catalog: AppStarCatalog())
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

    func testSkyNowLoadsOnlyLowEarthOrbitCandidates() async throws {
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
        XCTAssertEqual(model.state.satellites.content?.map(\.noradIndex), [25544])
    }

    func testSatelliteSearchDoesNotPublishASupersededQuery() async throws {
        let lines = String(decoding: tle, as: UTF8.self).split(separator: "\n").map(String.init)
        let info = try SatelliteInfo(elements: Elements(lines[0], lines[1], lines[2]))
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

    func testSkyLocationChangeDoesNotLeavePredictionPermanentlyBusy() async {
        let started = expectation(description: "Prediction started")
        var pending: CheckedContinuation<[RealtimePropagationResult], Error>?
        let model = RealtimeSkyModel(state: .init(observer: observer), predict: { _, _, _ in
            try await withCheckedThrowingContinuation { pending = $0; started.fulfill() }
        })
        model.send(.propagateCurrentEphemerides([], observer: observer, julianDate: date.julianDate))
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
