import Foundation
import StarryNight

/// Immutable render catalog shared by UI, rasterization and notification workers.
/// Only the actor performs database I/O; all synchronous methods read this snapshot.
public struct AppStarCatalog: Sendable {
    public let snapshot: SkySnapshot
    public let namedBrightStars: [Star]
    private let catalog: StarCatalog

    public init(snapshot: SkySnapshot, catalog: StarCatalog = StarCatalog()) {
        self.snapshot = snapshot
        self.namedBrightStars = Array(snapshot.stars.filter { $0.info?.displayName != nil }
            .sorted { $0.magnitude == $1.magnitude ? $0.id < $1.id : $0.magnitude < $1.magnitude }.prefix(50))
        self.catalog = catalog
    }

    public static func load() async throws -> Self {
        let catalog = StarCatalog()
        let snapshot = try await catalog.snapshot(maximumMagnitude: 6.5)
        // Resolve this small set once, off the drawing path. No per-frame database work.
        let brightest = snapshot.stars.filter { $0.magnitude.isFinite && $0.magnitude > -10 }
            .sorted { $0.magnitude == $1.magnitude ? $0.id < $1.id : $0.magnitude < $1.magnitude }.prefix(50)
        var named: [Int: Star] = [:]
        for var star in brightest {
            star.info = try await catalog.starInfo(forID: star.id)
            named[star.id] = star
        }
        let stars = snapshot.stars.map { named[$0.id] ?? $0 }
        return Self(snapshot: SkySnapshot(stars: stars, constellations: snapshot.constellations,
            lines: snapshot.lines, starsByID: Dictionary(uniqueKeysWithValues: stars.map { ($0.id, $0) })), catalog: catalog)
    }

    public init() {
        self.init(snapshot: SkySnapshot(stars: [], constellations: [], lines: [:], starsByID: [:]))
    }

    public func brightestStars() -> [Star] { Array(snapshot.stars.prefix(299)) }
    public func stars(maximumMagnitude: Double) -> [Star] {
        snapshot.stars.filter { $0.magnitude <= maximumMagnitude }
    }
    public func allConstellations() -> Set<Constellation> { snapshot.constellations }
    public func constellationLines(for constellation: Constellation) -> [Constellation.Line] {
        snapshot.lines[constellation.id] ?? []
    }
    public func star(withId id: Int) -> Star? { snapshot.starsByID[id] }
    public func starInfo(forId id: Int) async throws -> StarInfo? {
        try await catalog.starInfo(forID: id)
    }
    public func closestStar(to coordinate: SIMD3<Double>, maximumMagnitude: Double?, maximumAngularDistance: Double?) -> Star? {
        let filtered = SkySnapshot(
            stars: maximumMagnitude.map { stars(maximumMagnitude: $0) } ?? snapshot.stars,
            constellations: [], lines: [:], starsByID: [:]
        )
        return filtered.closestStar(to: coordinate, maximumAngularDistance: maximumAngularDistance ?? .pi)
    }
}
