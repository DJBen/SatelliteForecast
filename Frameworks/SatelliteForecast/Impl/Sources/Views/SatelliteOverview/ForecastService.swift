import Foundation
import UIKit
import SatelliteForecast
import SatelliteKit
import SatelliteWidgetSupport
import StarryNight
import SolarSystem

public struct ForecastRequest: Equatable, Sendable {
    public let observer: LatLonAlt
    public let dateRange: ClosedRange<Double>
    public init(observer: LatLonAlt, dateRange: ClosedRange<Double>) {
        self.observer = observer
        self.dateRange = dateRange
    }
}

/// Owns file access and CPU prediction work off the main actor. Uses the existing
/// TLE cache filenames so migrated and legacy screens can share downloaded data.
public actor ForecastService {
    private let brightStars: [Star]
    private let cacheDirectory: URL
    private let fetch: @Sendable (URL) async throws -> Data
    private let now: @Sendable () -> Date

    public init(cacheDirectory: URL = OrbitalDataCache.directory,
                brightStars: [Star] = [],
                now: @escaping @Sendable () -> Date = { Date() },
                fetch: @escaping @Sendable (URL) async throws -> Data = { url in
                    var request = URLRequest(url: url)
                    request.timeoutInterval = 20
                    let (data, response) = try await URLSession.shared.data(for: request)
                    guard let response = response as? HTTPURLResponse, (200..<300).contains(response.statusCode) else {
                        throw ForecastServiceError.invalidResponse
                    }
                    return data
                }) {
        self.brightStars = brightStars.filter { $0.magnitude.isFinite && $0.magnitude > -10 && $0.magnitude <= 3.0 }
            .sorted { $0.magnitude < $1.magnitude }
        self.cacheDirectory = cacheDirectory
        try? FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        self.now = now
        self.fetch = fetch
    }

    public func passes(for satellite: SpecialSatellite, request: ForecastRequest) async throws -> [Pass] {
        let info = try await satelliteInfo(for: satellite)
        try Task.checkCancellation()
        let snapshots = try info.generateSnapshots(observer: request.observer, julianDateRange: request.dateRange, interval: 30)
        let passes = try info.findPasses(observer: request.observer, coarseSnapshots: snapshots,
            qsMag: info.qsMag, crossSectionArea: info.satCat?.rcs)
        try Task.checkCancellation()
        return passes.map(\.pass)
    }

    /// Sample only visible pass windows; propagation stays off the main actor.
    public func widgetTracks(for satellite: SpecialSatellite, request: ForecastRequest,
                             passes: [Pass]) async throws -> [Double: [WidgetSkyPoint]] {
        guard !passes.isEmpty else { return [:] }
        let info = try await satelliteInfo(for: satellite)
        var result: [Double: [WidgetSkyPoint]] = [:]
        for pass in passes {
            try Task.checkCancellation()
            let duration = (pass.set.julianDate - pass.rise.julianDate) * 86400
            let count = max(2, min(120, Int(ceil(duration / 10))))
            var points: [WidgetSkyPoint] = []
            for index in 0...count {
                let jd = pass.rise.julianDate + (pass.set.julianDate - pass.rise.julianDate) * Double(index) / Double(count)
                let snapshot = try SatelliteSnapshot(satelliteInfo: info, julianDate: jd, observer: request.observer)
                points.append(.init(azimuth: snapshot.position.azim, elevation: snapshot.position.elev,
                                    illuminated: pass.isIlluminated(at: jd)))
            }
            result[pass.rise.julianDate] = points
        }
        return result
    }

    /// Use the same catalog and equatorial-to-horizontal conversion as the in-app chart.
    public func widgetSkies(request: ForecastRequest, passes: [Pass]) throws -> [Double: WidgetSkyBackground] {
        var result: [Double: WidgetSkyBackground] = [:]
        for pass in passes {
            try Task.checkCancellation()
            let date = Date(julianDate: pass.culmination.julianDate)
            let visibleStars = Array(brightStars.filter { star in
                let horizontal = azel(time: date, site: LatLon(request.observer), cele: RADec(star.coordinate))
                return horizontal.elev > 0 && horizontal.azim.isFinite && horizontal.elev.isFinite
            }.prefix(80))
            let stars: [WidgetStar] = visibleStars.map { star in
                let horizontal = azel(time: date, site: LatLon(request.observer), cele: RADec(star.coordinate))
                return WidgetStar(position: .init(azimuth: horizontal.azim, elevation: horizontal.elev),
                    magnitude: star.magnitude, spectralClass: star.spectralClass)
            }
            let sun = azel(time: date, site: LatLon(request.observer),
                cele: RADec(SolarSystemBody.sun.eci(julianDay: pass.culmination.julianDate)))
            let rect = CGRect(x: 0, y: 0, width: 280, height: 280)
            let format = UIGraphicsImageRendererFormat()
            format.scale = 2
            var imagePNG: Data?
            UITraitCollection(userInterfaceStyle: .dark).performAsCurrent {
                imagePNG = UIGraphicsImageRenderer(size: rect.size, format: format).image { context in
                    SkyChartUtils.addRasterizedBackgroundSkyPath(to: context,
                        params: .init(rect: rect, stars: visibleStars, constellations: [],
                            observer: request.observer, julianDate: pass.culmination.julianDate,
                            starColor: .white, constellationLineColor: .clear,
                            magToRadius: { max(0.6, min(1.9, 1.65 - 0.3 * $0)) }),
                        starManager: nil)
                    SkyChartUtils.addUnlabeledPlanetsAndMoon(to: context, rect: rect,
                        observer: request.observer, julianDate: pass.culmination.julianDate)
                }.pngData()
            }
            result[pass.rise.julianDate] = .init(stars: Array(stars.prefix(80)),
                sun: .init(azimuth: sun.azim, elevation: sun.elev), imagePNG: imagePNG)
        }
        return result
    }

    func satelliteInfo(for satellite: SpecialSatellite) async throws -> SatelliteInfo {
        try Task.checkCancellation()
        let file = cacheDirectory.appendingPathComponent(satellite.category.localFilename).appendingPathExtension("txt")
        if let attributes = try? FileManager.default.attributesOfItem(atPath: file.path),
           let modified = attributes[.modificationDate] as? Date,
           (0...21_600).contains(now().timeIntervalSince(modified)),
           let cached = try? Data(contentsOf: file),
           let info = try? parse(cached, satellite: satellite) {
            try Task.checkCancellation()
            return info
        }
        do {
            let data = try await fetch(satellite.category.url)
            try Task.checkCancellation()
            let info = try parse(data, satellite: satellite)
            // Validate before replacing a usable offline cache. Atomic writes also protect
            // legacy readers from observing a partially written TLE file.
            try? data.write(to: file, options: .atomic)
            return info
        } catch {
            if error is CancellationError || Task.isCancelled { throw CancellationError() }
            if let cached = try? Data(contentsOf: file), let info = try? parse(cached, satellite: satellite) {
                return info
            }
            throw error
        }
    }

    private func parse(_ data: Data, satellite: SpecialSatellite) throws -> SatelliteInfo {
        guard let elements = try OrbitalDataCache.elements(from: data)
            .filter({ $0.noradIndex == satellite.rawValue })
            .max(by: { $0.t₀ < $1.t₀ }) else {
            throw ForecastServiceError.missingSatellite(satellite.rawValue)
        }
        return try SatelliteInfo(elements: elements)
    }
}

public enum ForecastServiceError: LocalizedError {
    case invalidResponse
    case missingSatellite(UInt)
    public var errorDescription: String? {
        switch self {
        case .invalidResponse: return AppLocalization.text("Unable to download orbital data. Please try again.")
        case .missingSatellite(let id): return AppLocalization.format("The orbital data does not contain satellite %@.", String(id))
        }
    }
}
