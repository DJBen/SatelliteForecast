import Foundation
import SatelliteCatalog
import SQLite
import Testing
@testable import SatelliteCatalogImpl_SQLite

struct SatelliteMetadataStoreTests {
    @Test func concurrentReadersShareDecodedRecordsAndMissingResults() async throws {
        let store = SatelliteMetadataStore()
        try await withThrowingTaskGroup(of: Void.self) { group in
            for index in 0..<64 {
                group.addTask {
                    let id = index.isMultiple(of: 2) ? 25544 : 999999
                    let value = try await store.metadata(for: id)
                    #expect(value.satCat?.noradID == (id == 25544 ? id : nil))
                    if id == 999999 { #expect(value.ucsSat == nil) }
                }
            }
            try await group.waitForAll()
        }
        #expect(await store.databaseLookupCount == 2)
        #expect(await store.cachedRecordCount == 2)
    }

    @Test func cacheEvictionIsBoundedAndReloadsCorrectly() async throws {
        let store = SatelliteMetadataStore(capacity: 2)
        let original = try await store.metadata(for: 25544)
        _ = try await store.metadata(for: 47302)
        _ = try await store.metadata(for: 999999)
        #expect(await store.cachedRecordCount == 2)
        #expect(try await store.metadata(for: 25544) == original)
        #expect(await store.databaseLookupCount == 4)
        #expect(await store.cachedRecordCount == 2)
    }

    @Test func cancelledLookupDoesNotPopulateCache() async throws {
        let store = SatelliteMetadataStore()
        let task = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            return try await store.metadata(for: 25544)
        }
        do {
            _ = try await task.value
            Issue.record("Expected cancellation")
        } catch is CancellationError { }
        #expect(await store.databaseLookupCount == 0)
        #expect(await store.cachedRecordCount == 0)
        #expect(try await store.metadata(for: 25544).satCat?.noradID == 25544)
    }

    @Test func inclinationAndUTCLaunchDatesMatchBundledData() async throws {
        let store = SatelliteMetadataStore()
        let iss = try #require(await store.metadata(for: 25544).satCat)
        #expect(iss.inclination == 51.64)
        #expect(iss.period == 92.93)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        #expect(iss.launchDate == calendar.date(from: DateComponents(year: 1998, month: 11, day: 20)))
        let lateDecember = try #require(await store.metadata(for: 47302).ucsSat)
        #expect(lateDecember.dateOfLaunch == calendar.date(from: DateComponents(year: 2020, month: 12, day: 27)))
    }

    @Test func bundledLookupsUseIndexes() throws {
        let database = try Connection(Bundle.module.url(forResource: "satellites", withExtension: "sqlite")!.path,
                                      readonly: true)
        for (table, column) in [("SatCat", "NORAD_CAT_ID"), ("UCS", "NORADNumber")] {
            let rows = try database.prepare("EXPLAIN QUERY PLAN SELECT * FROM \(table) WHERE \(column) = ? LIMIT 1", 25544)
            let plan = rows.map { String(describing: $0[3]) }.joined()
            #expect(plan.contains("SEARCH"))
            #expect(!plan.contains("SCAN"))
        }
    }

    @available(macOS 13, *)
    @Test func warmCatalogAvoidsDatabaseAndDecoding() async throws {
        let store = SatelliteMetadataStore()
        let database = try Connection(Bundle.module.url(forResource: "satellites", withExtension: "sqlite")!.path,
                                      readonly: true)
        let ids = try database.prepare("SELECT NORADNumber FROM UCS ORDER BY NORADNumber LIMIT 100")
            .map { Int($0[0] as! Int64) }
        let clock = ContinuousClock()
        let coldStart = clock.now
        for id in ids { _ = try await store.metadata(for: id) }
        let cold = coldStart.duration(to: clock.now)
        let warmStart = clock.now
        for id in ids { _ = try await store.metadata(for: id) }
        let warm = warmStart.duration(to: clock.now)
        print("Metadata benchmark, 100 records: cold \(cold), warm \(warm)")
        // Assert work avoided, not a machine-dependent wall-clock threshold.
        #expect(await store.databaseLookupCount == Set(ids).count)
    }
}
