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

    func testAirMass() {
        XCTAssertEqual(AstroAlgorithms.airMass(zenithAngle: 0), 1, accuracy: 0.01)
        XCTAssertEqual(AstroAlgorithms.airMass(zenithAngle: .pi / 2), 31, accuracy: 1)
        XCTAssertEqual(AstroAlgorithms.airMass(zenithAngle: .pi / 6), 1.1547, accuracy: 0.01)
        XCTAssertEqual(AstroAlgorithms.airMass(zenithAngle: .pi / 4), 1.4142, accuracy: 0.01)
    }
}
