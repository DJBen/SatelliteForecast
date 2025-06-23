//
//  SatelliteForecastTests.swift
//  SatelliteForecastTests
//
//  Created by Ben Lu on 6/2/21.
//

import XCTest
@testable import SatelliteForecast
@preconcurrency import SatelliteKit

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

    func testSatelliteMagnitude() {
        let issMagnitude = AstroAlgorithms.satelliteMagnitude(
            instrinsicMagnitude: -2.5,
            range: 408,
            phaseAngle: .pi / 4,
            zenithAngle: 0
        )
        XCTExpectFailure()
        XCTAssertEqual(issMagnitude, -1.5, accuracy: 0.1)

        let sl16rbMagitude = AstroAlgorithms.satelliteMagnitude(
            instrinsicMagnitude: 2.0,
            range: 850,
            phaseAngle: .pi / 3,
            zenithAngle: 0
        )
        XCTAssertEqual(sl16rbMagitude, 4.2, accuracy: 0.1)
    }

    func testLambertianSphereMagnitude() {
        let issMagnitude = AstroAlgorithms.lambertianSphereMagnitude(
            crossSectionArea: 399.0524,
            range: 408_000,
            phaseAngle: .pi / 4,
            albedo: 0.2
        )
        XCTAssertEqual(issMagnitude, -1.5, accuracy: 0.1)

        let sl16rbMagitude = AstroAlgorithms.lambertianSphereMagnitude(
            crossSectionArea: 11.2276,
            range: 850_000,
            phaseAngle: .pi / 3,
            albedo: 0.2
        )
        XCTAssertEqual(sl16rbMagitude, 4.2, accuracy: 0.1)
    }
}
