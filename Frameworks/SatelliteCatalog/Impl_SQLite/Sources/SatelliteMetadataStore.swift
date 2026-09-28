import Foundation
import SatelliteCatalog
import SQLite

public struct SatelliteMetadata: Sendable, Equatable {
    public let satCat: SatCat?
    public let ucsSat: UCSSat?
}

/// Owns the read-only connection and decoded records. No SQLite object crosses
/// isolation boundaries; callers receive immutable, Sendable values.
public actor SatelliteMetadataStore {
    public static let shared = SatelliteMetadataStore()

    private var database: Connection?
    private var cache: [Int: SatelliteMetadata] = [:]
    private var insertionOrder: [Int] = []
    private var evictionIndex = 0
    private let capacity: Int
    // Internal diagnostics for regression tests; never sent to analytics.
    private(set) var databaseLookupCount = 0
    var cachedRecordCount: Int { cache.count }

    init(capacity: Int = 2048) {
        precondition(capacity > 0)
        self.capacity = capacity
    }

    public func metadata(for noradID: Int) throws -> SatelliteMetadata {
        try Task.checkCancellation()
        if let cached = cache[noradID] { return cached }
        if database == nil {
            database = try Connection(
                Bundle.module.url(forResource: "satellites", withExtension: "sqlite")!.path,
                readonly: true)
        }
        let database = database!
        let satCat = try database.pluck(SatelliteCatalog.SatCatTable.tableName.filter(
            SatelliteCatalog.SatCatTable.noradCatID == noradID)).flatMap(SatCat.init(row:))
        try Task.checkCancellation()
        let ucsSat = try database.pluck(SatelliteCatalog.UCSSatTable.tableName.filter(
            SatelliteCatalog.UCSSatTable.noradID == noradID)).flatMap(UCSSat.init(row:))
        try Task.checkCancellation()
        let result = SatelliteMetadata(satCat: satCat, ucsSat: ucsSat)
        databaseLookupCount += 1
        // Cache missing records too: many current satellites postdate this bundle.
        // FIFO bounds memory without sorting or scanning on every lookup.
        if insertionOrder.count == capacity {
            cache.removeValue(forKey: insertionOrder[evictionIndex])
            insertionOrder[evictionIndex] = noradID
            evictionIndex = (evictionIndex + 1) % capacity
        } else {
            insertionOrder.append(noradID)
        }
        cache[noradID] = result
        return result
    }
}
