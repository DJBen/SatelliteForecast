import CoreLocation
import Foundation
import Observation
import SatelliteForecast
import SatelliteKit
import SatelliteWidgetSupport

public struct ForecastInput: Equatable {
    public var observer: LatLonAlt?
    public var frozenJulianDate: Double?
    public var julianDateOffset: Double
    public var authorizationStatus: CLAuthorizationStatus
    public init(observer: LatLonAlt? = nil, julianDateOffset: Double = 0, frozenJulianDate: Double? = nil,
                authorizationStatus: CLAuthorizationStatus = .notDetermined) {
        self.observer = observer
        self.julianDateOffset = julianDateOffset
        self.frozenJulianDate = frozenJulianDate
        self.authorizationStatus = authorizationStatus
    }
    public var isMissingLocation: Bool {
        observer == nil && [.notDetermined, .restricted, .denied].contains(authorizationStatus)
    }
}

@MainActor
public struct ForecastClient {
    public var load: @MainActor (SpecialSatellite, ForecastRequest) async throws -> [Pass]
    public var satelliteInfo: @MainActor (SpecialSatellite) async throws -> SatelliteInfo?
    public var widgetTracks: @MainActor (SpecialSatellite, ForecastRequest, [Pass]) async throws -> [Double: [WidgetSkyPoint]]
    public var widgetSkies: @MainActor (ForecastRequest, [Pass]) async throws -> [Double: WidgetSkyBackground]
    public var widgetDomes: @MainActor (SpecialSatellite, ForecastRequest, [Pass]) async throws -> [Double: WidgetDome]
    public var now: @MainActor () -> Date
    public var sleep: @MainActor (Duration) async throws -> Void
    public init(load: @escaping @MainActor (SpecialSatellite, ForecastRequest) async throws -> [Pass],
                satelliteInfo: @escaping @MainActor (SpecialSatellite) async throws -> SatelliteInfo? = { _ in nil },
                widgetTracks: @escaping @MainActor (SpecialSatellite, ForecastRequest, [Pass]) async throws -> [Double: [WidgetSkyPoint]] = { _, _, _ in [:] },
                widgetSkies: @escaping @MainActor (ForecastRequest, [Pass]) async throws -> [Double: WidgetSkyBackground] = { _, _ in [:] },
                widgetDomes: @escaping @MainActor (SpecialSatellite, ForecastRequest, [Pass]) async throws -> [Double: WidgetDome] = { _, _, _ in [:] },
                now: @escaping @MainActor () -> Date = { Date() },
                sleep: @escaping @MainActor (Duration) async throws -> Void = { try await Task.sleep(for: $0) }) {
        self.load = load
        self.satelliteInfo = satelliteInfo
        self.now = now
        self.widgetTracks = widgetTracks
        self.widgetSkies = widgetSkies
        self.widgetDomes = widgetDomes
        self.sleep = sleep
    }
    public static func live(service: ForecastService) -> Self {
        Self(load: { try await service.passes(for: $0, request: $1) },
             satelliteInfo: { try await service.satelliteInfo(for: $0) },
             widgetTracks: { try await service.widgetTracks(for: $0, request: $1, passes: $2) },
             widgetSkies: { try await service.widgetSkies(request: $0, passes: $1) },
             widgetDomes: { try await service.widgetDomes(for: $0, request: $1, passes: $2) })
    }
}

@MainActor
@Observable
public final class ForecastModel {
    public private(set) var currentDate: Date
    public private(set) var issNextPass: Loadable<NextPass, Error>
    public private(set) var tianheNextPass: Loadable<NextPass, Error>
    public private(set) var upcomingPasses: [Pass] = []
    @ObservationIgnored private let client: ForecastClient
    @ObservationIgnored private var generation = 0
    @ObservationIgnored private var passes: [SpecialSatellite: [Pass]] = [:]
    @ObservationIgnored private var lastRefresh: Date?
    /// True once any refresh has started, so a second screen can avoid restarting the forecast.
    public var hasRefreshed: Bool { lastRefresh != nil }

    public init(client: ForecastClient,
                issNextPass: Loadable<NextPass, Error> = .loading,
                tianheNextPass: Loadable<NextPass, Error> = .loading) {
        self.client = client
        self.currentDate = client.now()
        self.issNextPass = issNextPass
        self.tianheNextPass = tianheNextPass
    }

    func satelliteInfo(for satellite: SpecialSatellite) async throws -> SatelliteInfo? {
        try await client.satelliteInfo(satellite)
    }

    /// The view owns this task. Countdown updates use the injected clock; expensive
    /// forecasts refresh hourly or when location/debug time changes, not every tick.
    public func run(_ input: ForecastInput) async {
        await refresh(input)
        while !Task.isCancelled {
            do { try await client.sleep(.seconds(1)); try Task.checkCancellation() }
            catch { return }
            currentDate = client.now()
            if let lastRefresh, currentDate.timeIntervalSince(lastRefresh) >= 3600 {
                await refresh(input)
            } else {
                updateNextPasses(input: input)
            }
        }
    }

    public func refresh(_ input: ForecastInput) async {
        guard !Task.isCancelled else { return }
        generation += 1
        let requestGeneration = generation
        currentDate = client.now()
        lastRefresh = currentDate
        passes = [:]
        // The widget keeps the last saved forecast until this refresh replaces it, so launching
        // and leaving the app before the forecast finishes never blanks it. LocationService
        // discards the saved forecast when the observer moves far enough to make it wrong.
        upcomingPasses = []
        issNextPass = .loading
        tianheNextPass = .loading
        guard let observer = input.observer else {
            AppAnalytics.event("flow_blocked", screen: .forecast, parameters: ["reason": "missing_location"])
            return
        }
        let request = ForecastRequest(observer: observer,
            dateRange: JulianDateUtil.createJulianDateRange(now: input.frozenJulianDate ?? (currentDate.julianDate + input.julianDateOffset)))
        async let iss: Void = load(.iss, request: request, generation: requestGeneration, input: input)
        async let tianhe: Void = load(.tianhe, request: request, generation: requestGeneration, input: input)
        _ = await (iss, tianhe)
        guard requestGeneration == generation, !Task.isCancelled, input.julianDateOffset == 0 && input.frozenJulianDate == nil,
              !isWidgetTest, passes[.iss] != nil, passes[.tianhe] != nil else { return }
        var summaries: [WidgetPass] = []
        let loadedPasses = passes
        for (satellite, found) in loadedPasses {
            let visible = found.filter { ($0.highestIlluminated?.elev ?? 0) > 10 && $0.sunElevationAtTransit < -6 }
            let tracks = (try? await client.widgetTracks(satellite, request, visible)) ?? [:]
            guard requestGeneration == generation, !Task.isCancelled else { return }
            let skies = (try? await client.widgetSkies(request, visible)) ?? [:]
            guard requestGeneration == generation, !Task.isCancelled else { return }
            let domes = (try? await client.widgetDomes(satellite, request, visible)) ?? [:]
            guard requestGeneration == generation, !Task.isCancelled else { return }
            for pass in visible {
                let summary = WidgetPass(station: Int(pass.noradIndex),
                    rise: Date(julianDate: pass.rise.julianDate),
                    peak: Date(julianDate: pass.culmination.julianDate),
                    set: Date(julianDate: pass.set.julianDate), elevation: pass.culmination.elev,
                    startDirection: Self.direction(pass.rise.azim), endDirection: Self.direction(pass.set.azim),
                    skyTrack: tracks[pass.rise.julianDate], skyBackground: skies[pass.rise.julianDate],
                    events: Self.widgetEvents(pass), dome: domes[pass.rise.julianDate])
                summaries.append(summary)
            }
        }
        WidgetForecastStore.write(.init(generated: currentDate,
            expires: min(Date(julianDate: request.dateRange.upperBound), currentDate.addingTimeInterval(3 * 86_400)),
            passes: summaries))
    }

    private var isWidgetTest: Bool {
        NSClassFromString("XCTestCase") != nil ||
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil ||
        ProcessInfo.processInfo.environment["SATELLITE_SNAPSHOT_TESTS"] == "1" ||
        ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
    }

    /// Rise, culmination, set and each shadow crossing, in time order.
    static func widgetEvents(_ pass: Pass) -> [WidgetSkyEvent] {
        func event(_ kind: WidgetSkyEvent.Kind, _ position: Pass.DatePosition) -> WidgetSkyEvent {
            .init(kind: kind, date: Date(julianDate: position.julianDate),
                  position: .init(azimuth: position.azim, elevation: max(0, position.elev)))
        }
        var events = [event(.rise, pass.rise), event(.peak, pass.culmination), event(.set, pass.set)]
        for change in pass.illumination.changes {
            switch change {
            case .entersShadow(let position): events.append(event(.entersShadow, position))
            case .exitsShadow(let position): events.append(event(.exitsShadow, position))
            }
        }
        return events.sorted { $0.date < $1.date }
    }

    private static func direction(_ azimuth: Double) -> String {
        let normalized = (azimuth.truncatingRemainder(dividingBy: 360) + 360).truncatingRemainder(dividingBy: 360)
        return ["N", "NE", "E", "SE", "S", "SW", "W", "NW"][Int((normalized / 45).rounded()) % 8]
    }

    private func load(_ satellite: SpecialSatellite, request: ForecastRequest, generation expected: Int, input: ForecastInput) async {
        let metric = AppAnalytics.Operation(satellite == .iss ? "forecast_iss" : "forecast_tiangong", screen: .forecast)
        defer { metric.finish("cancelled") }
        do {
            let found = try await client.load(satellite, request)
            try Task.checkCancellation()
            guard expected == generation else { return }
            metric.finish(found.isEmpty ? "empty" : "success", count: found.count)
            passes[satellite] = found
            updateNextPasses(input: input)
        } catch {
            guard expected == generation, !Task.isCancelled, !(error is CancellationError) else { return }
            metric.finish("failure", reason: "load_failed")
            if satellite == .iss { issNextPass = .failed(error) }
            else { tianheNextPass = .failed(error) }
        }
    }

    private func updateNextPasses(input: ForecastInput) {
        let now = input.frozenJulianDate ?? (currentDate.julianDate + input.julianDateOffset)
        upcomingPasses = ObservationOpportunity.upcoming(passes.values.flatMap { $0 }, now: now)
        for (satellite, found) in passes {
            let next = NextPass(
                nextVisiblePass: found.first { $0.set.julianDate >= now && ($0.highestIlluminated?.elev ?? 0) > 10 && $0.sunElevationAtTransit < -6 },
                nextProminentPass: found.first { $0.set.julianDate >= now && ($0.highestIlluminated?.elev ?? 0) > 45 && $0.sunElevationAtTransit < -6 })
            if satellite == .iss { issNextPass = .loaded(next) }
            else { tianheNextPass = .loaded(next) }
        }
    }
}
