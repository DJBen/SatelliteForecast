//
//  SatelliteForecastCoreTests.swift
//  SatelliteForecastCoreTests
//
//  Created by Ben Lu on 6/2/21.
//

import XCTest
@testable import SatelliteForecastCore
import SatelliteKit

class AstroAlgorithmsTests: XCTestCase {
    func testLineOfSight() {
        let r1 = Vector(0, -4464.696, -5102.509)
        let r2 = Vector(0, 5740.323, 3189.068)
        XCTAssertFalse(AstroAlgorithms.hasLineOfSight(object1Geo: r1, object2Geo: r2))
        let sun = Vector(122_233_179, -76_150_708, -33_016_374)
        XCTAssertTrue(AstroAlgorithms.hasLineOfSight(object1Geo: r1, object2Geo: sun))
    }
}
