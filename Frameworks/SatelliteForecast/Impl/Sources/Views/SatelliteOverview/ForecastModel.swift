import CoreLocation
import Foundation
import Observation
import SatelliteForecast
import SatelliteKit

public struct ForecastInput: Equatable {
    public var observer: LatLonAlt?
    public var julianDateOffset: Double
    public var authorizationStatus: CLAuthorizationStatus
    public init(observer: LatLonAlt? = nil, julianDateOffset: Double = 0,
                authorizationStatus: CLAuthorizationStatus = .notDetermined) {
        self.observer = observer
        self.julianDateOffset = julianDateOffset
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
    public var now: @MainActor () -> Date
    public var sleep: @MainActor (Duration) async throws -> Void
    public init(load: @escaping @MainActor (SpecialSatellite, ForecastRequest) async throws -> [Pass],
                satelliteInfo: @escaping @MainActor (SpecialSatellite) async throws -> SatelliteInfo? = { _ in nil },
                now: @escaping @MainActor () -> Date = { Date() },
                sleep: @escaping @MainActor (Duration) async throws -> Void = { try await Task.sleep(for: $0) }) {
        self.load = load
        self.satelliteInfo = satelliteInfo
        self.now = now
        self.sleep = sleep
    }
    public static func live(service: ForecastService) -> Self {
        Self(load: { try await service.passes(for: $0, request: $1) },
             satelliteInfo: { try await service.satelliteInfo(for: $0) })
    }
}

@MainActor
@Observable
public final class ForecastModel {
    public private(set) var currentDate: Date
    public private(set) var issNextPass: Loadable<NextPass, Error>
    public private(set) var tianheNextPass: Loadable<NextPass, Error>
    @ObservationIgnored private let client: ForecastClient
    @ObservationIgnored private var generation = 0
    @ObservationIgnored private var passes: [SpecialSatellite: [Pass]] = [:]
    @ObservationIgnored private var lastRefresh: Date?

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
            do { try await client.sleep(.seconds(10)); try Task.checkCancellation() }
            catch { return }
            currentDate = client.now()
            if let lastRefresh, currentDate.timeIntervalSince(lastRefresh) >= 3600 {
                await refresh(input)
            } else {
                updateNextPasses(offset: input.julianDateOffset)
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
        issNextPass = .loading
        tianheNextPass = .loading
        guard let observer = input.observer else {
            AppAnalytics.event("flow_blocked", screen: .forecast, parameters: ["reason": "missing_location"])
            return
        }
        let request = ForecastRequest(observer: observer,
            dateRange: JulianDateUtil.createJulianDateRange(now: currentDate.julianDate + input.julianDateOffset))
        async let iss: Void = load(.iss, request: request, generation: requestGeneration, offset: input.julianDateOffset)
        async let tianhe: Void = load(.tianhe, request: request, generation: requestGeneration, offset: input.julianDateOffset)
        _ = await (iss, tianhe)
    }

    private func load(_ satellite: SpecialSatellite, request: ForecastRequest, generation expected: Int, offset: Double) async {
        let metric = AppAnalytics.Operation(satellite == .iss ? "forecast_iss" : "forecast_tiangong", screen: .forecast)
        defer { metric.finish("cancelled") }
        do {
            let found = try await client.load(satellite, request)
            try Task.checkCancellation()
            guard expected == generation else { return }
            metric.finish(found.isEmpty ? "empty" : "success", count: found.count)
            passes[satellite] = found
            updateNextPasses(offset: offset)
        } catch {
            guard expected == generation, !Task.isCancelled, !(error is CancellationError) else { return }
            metric.finish("failure", reason: "load_failed")
            if satellite == .iss { issNextPass = .failed(error) }
            else { tianheNextPass = .failed(error) }
        }
    }

    private func updateNextPasses(offset: Double) {
        let now = currentDate.julianDate + offset
        for (satellite, found) in passes {
            let next = NextPass(
                nextVisiblePass: found.first { $0.set.julianDate >= now && ($0.highestIlluminated?.elev ?? 0) > 10 && $0.sunElevationAtTransit < -6 },
                nextProminentPass: found.first { $0.set.julianDate >= now && ($0.highestIlluminated?.elev ?? 0) > 45 && $0.sunElevationAtTransit < -6 })
            if satellite == .iss { issNextPass = .loaded(next) }
            else { tianheNextPass = .loaded(next) }
        }
    }
}
