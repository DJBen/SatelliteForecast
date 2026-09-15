import Foundation
import SatelliteForecast
import SatelliteKit

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
    private let cacheDirectory: URL
    private let fetch: @Sendable (URL) async throws -> Data
    private let now: @Sendable () -> Date

    public init(cacheDirectory: URL = OrbitalDataCache.directory,
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
        case .invalidResponse: return "Unable to download orbital data. Please try again."
        case .missingSatellite(let id): return "The orbital data does not contain satellite \(id)."
        }
    }
}
