import XCTest
import StarryNight
import UIKit
import SatelliteForecast
@testable import SatelliteForecastImpl

final class CatalogIntegrationTests: XCTestCase {
    func testAppLoadsNewCatalogWithCompleteConstellationEndpoints() async throws {
        let catalog = try await AppStarCatalog.load()
        XCTAssertEqual(catalog.brightestStars().count, 299)
        XCTAssertGreaterThan(catalog.stars(maximumMagnitude: 6).count, 299)
        for constellation in catalog.allConstellations() {
            for line in catalog.constellationLines(for: constellation) {
                XCTAssertNotNil(catalog.star(withId: line.star1Id))
                XCTAssertNotNil(catalog.star(withId: line.star2Id))
            }
        }
        let first = try XCTUnwrap(catalog.brightestStars().first)
        XCTAssertEqual(catalog.closestStar(to: first.coordinate, maximumMagnitude: 6, maximumAngularDistance: 0)?.id, first.id)
        let info = try await catalog.starInfo(forId: first.id)
        XCTAssertNotNil(info?.properName)
    }

    func testRenderingUsesImmutableDataAcrossConcurrentWorkers() async throws {
        let catalog = try await AppStarCatalog.load()
        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<20 {
                group.addTask {
                    XCTAssertEqual(catalog.brightestStars().count, 299)
                    XCTAssertFalse(catalog.allConstellations().isEmpty)
                    XCTAssertTrue(catalog.stars(maximumMagnitude: 4.5).allSatisfy { $0.magnitude <= 4.5 })
                }
            }
        }
    }
}
