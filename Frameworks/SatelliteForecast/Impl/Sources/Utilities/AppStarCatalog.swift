import Foundation
import StarryNight

/// Immutable render catalog shared by UI, rasterization and notification workers.
/// Only the actor performs database I/O; all synchronous methods read this snapshot.
public struct AppStarCatalog: Sendable {
    public let snapshot: SkySnapshot
    private let catalog: StarCatalog

    public init(snapshot: SkySnapshot, catalog: StarCatalog = StarCatalog()) {
        self.snapshot = snapshot
        self.catalog = catalog
    }

    public static func load() async throws -> Self {
        let catalog = StarCatalog()
        return try await Self(snapshot: catalog.snapshot(maximumMagnitude: 6.5), catalog: catalog)
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
