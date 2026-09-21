import Foundation
import simd
import Ch3
import StarryNight

/// Convex spherical frustum in catalog (J2000) coordinates. No longitude arithmetic.
struct PlanetariumStarViewport: Sendable {
    let forward: SIMD3<Double>
    let right: SIMD3<Double>
    let up: SIMD3<Double>
    let horizontalHalfAngle: Double
    let verticalHalfAngle: Double

    init(forward: SIMD3<Float>, right: SIMD3<Float>, up: SIMD3<Float>, fieldOfView: Double, aspect: Double) {
        self.forward = simd_normalize(SIMD3<Double>(forward))
        self.right = simd_normalize(SIMD3<Double>(right))
        self.up = simd_normalize(SIMD3<Double>(up))
        verticalHalfAngle = fieldOfView * .pi / 360
        horizontalHalfAngle = atan(tan(verticalHalfAngle) * aspect)
    }

    private init(_ view: Self, padding: Double) {
        forward = view.forward; right = view.right; up = view.up
        horizontalHalfAngle = min(89 * .pi / 180, view.horizontalHalfAngle + padding)
        verticalHalfAngle = min(89 * .pi / 180, view.verticalHalfAngle + padding)
    }

    func padded(by radians: Double = 2 * .pi / 180) -> Self { Self(self, padding: radians) }

    var planes: [SIMD3<Double>] {
        [simd_normalize(forward * tan(horizontalHalfAngle) + right),
         simd_normalize(forward * tan(horizontalHalfAngle) - right),
         simd_normalize(forward * tan(verticalHalfAngle) + up),
         simd_normalize(forward * tan(verticalHalfAngle) - up)]
    }

    var corners: [SIMD3<Double>] {
        [-1.0, 1.0].flatMap { x in
            [-1.0, 1.0].map { y in
                simd_normalize(forward + right * (x * tan(horizontalHalfAngle)) + up * (y * tan(verticalHalfAngle)))
            }
        }
    }

    func contains(_ view: Self) -> Bool {
        let bounds = planes
        return view.corners.allSatisfy { corner in bounds.allSatisfy { simd_dot($0, corner) >= -1e-12 } }
    }
}

struct PlanetariumStarRegionKey: Hashable, Sendable {
    let cell: UInt64
    let magnitude: Double
}

struct PlanetariumStarRegion: Sendable {
    let key: PlanetariumStarRegionKey
    let stars: [Star]
}

struct PlanetariumStarRegionIndex: Sendable {
    struct Cell: Sendable {
        let id: UInt64
        let resolution: Int
        let center: SIMD3<Double>
        let radius: Double
    }
    let cells: [Cell]

    init() throws {
        var roots = [H3Index](repeating: 0, count: Int(res0CellCount()))
        guard getRes0Cells(&roots) == 0 else { throw IndexError.invalidGeometry }
        var cells: [Cell] = []
        for resolution in 0...2 {
            for root in roots {
                var count: Int64 = 0
                guard cellToChildrenSize(root, Int32(resolution), &count) == 0 else { throw IndexError.invalidGeometry }
                var children = [H3Index](repeating: 0, count: Int(count))
                guard cellToChildren(root, Int32(resolution), &children) == 0 else { throw IndexError.invalidGeometry }
                for id in children where id != 0 {
                    var coordinate = LatLng()
                    var boundary = CellBoundary()
                    guard cellToLatLng(id, &coordinate) == 0, cellToBoundary(id, &boundary) == 0 else {
                        throw IndexError.invalidGeometry
                    }
                    let center = Self.direction(coordinate)
                    let count = Int(boundary.numVerts)
                    let radius = withUnsafePointer(to: &boundary.verts) { pointer in
                        pointer.withMemoryRebound(to: LatLng.self, capacity: 10) { vertices in
                            (0..<count).map { i in
                                let vertex = Self.direction(vertices[i])
                                return atan2(simd_length(simd_cross(center, vertex)), simd_dot(center, vertex))
                            }.max() ?? 0
                        }
                    }
                    // H3 inserts vertices at icosahedron face crossings. Its great-circle
                    // edges lie inside this (< hemisphere) convex cap, including pentagons.
                    cells.append(Cell(id: id, resolution: resolution, center: center, radius: radius + 1e-7))
                }
            }
        }
        self.cells = cells
    }

    func visible(in viewport: PlanetariumStarViewport, magnitude: Double) -> [PlanetariumStarRegionKey] {
        let planes = viewport.planes
        return cells.filter { cell in
            // Reject only when the entire bounding cap lies outside a viewport plane.
            // Conservative at edges/corners: false positives are safe; missing cells are not.
            planes.allSatisfy { simd_dot($0, cell.center) >= -sin(cell.radius) }
        }.sorted {
            if $0.resolution != $1.resolution { return $0.resolution < $1.resolution }
            let a = simd_dot($0.center, viewport.forward), b = simd_dot($1.center, viewport.forward)
            return a == b ? $0.id < $1.id : a > b
        }.map { .init(cell: $0.id, magnitude: magnitude) }
    }

    private static func direction(_ coordinate: LatLng) -> SIMD3<Double> {
        SIMD3(cos(coordinate.lat) * cos(coordinate.lng), cos(coordinate.lat) * sin(coordinate.lng), sin(coordinate.lat))
    }
    private enum IndexError: Error { case invalidGeometry }
}

/// Indexed SQLite reads and geometry construction are confined to this actor.
/// Cache each magnitude separately, including empty cells, and bound retained CPU data.
actor PlanetariumRegionalStarCatalog {
    private var manager: StarManager?
    private var index: PlanetariumStarRegionIndex?
    private var cache: [PlanetariumStarRegionKey: (stars: [Star], stamp: Int)] = [:]
    private var clock = 0
    private(set) var queryCount = 0
    private(set) var cachedStarCount = 0
    var cachedCellCount: Int { cache.count }
    let cellBudget: Int
    let starBudget: Int

    init(cellBudget: Int = 512, starBudget: Int = 20_000) {
        self.cellBudget = cellBudget; self.starBudget = starBudget
    }

    func regions(in viewport: PlanetariumStarViewport, magnitude: Double) throws -> [PlanetariumStarRegionKey] {
        try Task.checkCancellation()
        if index == nil { index = try PlanetariumStarRegionIndex() }
        try Task.checkCancellation()
        return index!.visible(in: viewport, magnitude: magnitude)
    }

    func load(_ keys: [PlanetariumStarRegionKey]) throws -> [PlanetariumStarRegion] {
        var result: [PlanetariumStarRegion] = []
        for key in keys {
            try Task.checkCancellation()
            clock += 1
            let stars: [Star]
            if let cached = cache[key] {
                stars = cached.stars
            } else {
                if manager == nil { manager = try StarManager() }
                // The shared magnitude-6.5 snapshot supplies the base layer. Never duplicate it.
                stars = manager!.stars(inH3Cell: key.cell, maximumMagnitude: key.magnitude).filter { $0.magnitude > 6.5 }
                queryCount += 1
                cachedStarCount += stars.count
            }
            cache[key] = (stars, clock)
            result.append(.init(key: key, stars: stars))
            while cache.count > cellBudget || cachedStarCount > starBudget {
                guard let oldest = cache.min(by: { $0.value.stamp < $1.value.stamp }) else { break }
                cachedStarCount -= oldest.value.stars.count
                cache.removeValue(forKey: oldest.key)
            }
        }
        try Task.checkCancellation()
        return result
    }
}
