import Foundation
import SatelliteKit

/// Shared persistent cache for forecast and catalog screens. Unlike temporary files,
/// these validated downloads survive temporary-directory cleanup between launches.
public enum OrbitalDataCache {
    public static var directory: URL {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("OrbitalData", isDirectory: true)
    }
}

extension OrbitalDataCache {
    /// Accept modern OMM JSON and existing TLE caches during migration.
    static func elements(from data: Data) throws -> [Elements] {
        guard let text = String(data: data, encoding: .utf8) else {
            throw ForecastServiceError.invalidResponse
        }
        let result: [Elements]
        if text.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("[") {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .custom { decoder in
                let value = try decoder.singleValueContainer().decode(String.self)
                let formatter = ISO8601DateFormatter()
                formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                let utc = value.hasSuffix("Z") ? value : value + "Z"
                if let date = formatter.date(from: utc) { return date }
                formatter.formatOptions = [.withInternetDateTime]
                guard let date = formatter.date(from: utc) else {
                    throw ForecastServiceError.invalidResponse
                }
                return date
            }
            result = try decoder.decode([Elements].self, from: data)
        } else {
            let lines = text.split(whereSeparator: \.isNewline)
            guard !lines.isEmpty, lines.count.isMultiple(of: 3) else {
                throw ForecastServiceError.invalidResponse
            }
            result = try Elements.load(chunk: text)
        }
        guard !result.isEmpty, result.allSatisfy({
            $0.noradIndex > 0 && $0.n₀.isFinite && $0.n₀ > 0 &&
            $0.e₀.isFinite && (0..<1).contains($0.e₀) && $0.t₀.isFinite
        }) else { throw ForecastServiceError.invalidResponse }
        return result
    }
}
