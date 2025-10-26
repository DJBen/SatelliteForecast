//
//  SolarSystemBodyTests.swift
//  SolarSystem-Unit-Tests
//
//  Created by Ben Lu on 3/19/22.
//

import XCTest
import simd
@testable import SolarSystem

let appleZero: TimeInterval = 2451910.5   // 2001-Jan-01 00h00m00.0s (CFAbsoluteTime zero)
let day2sec = 24.0 * 60.0 * 60.0
let sec2day = 1.0 / day2sec

class SolarSystemTests: XCTestCase {
    func testApparentMagnitude() throws {
        // Test Venus apparent magnitude calculation
        // Using a known date for validation
        let formatter = ISO8601DateFormatter()
        let date = formatter.date(from: "2021-06-02T06:29:00-0600")!
        
        // Test Venus magnitude
        let venusMagnitude = SolarSystemBody.venus.apparentMagnitude(julianDay: date.julianDate)
        
        XCTAssertNotNil(venusMagnitude)
        // Venus apparent magnitude should typically be between -5 and -3
        XCTAssertTrue(venusMagnitude! > -5.0 && venusMagnitude! < -3.0, 
                     "Venus magnitude \(venusMagnitude!) is outside expected range")
        
        // Test Mars magnitude  
        let marsMagnitude = SolarSystemBody.mars.apparentMagnitude(julianDay: date.julianDate)
        
        XCTAssertNotNil(marsMagnitude)
        // Mars apparent magnitude should typically be between -3 and 2
        XCTAssertTrue(marsMagnitude! > -3.0 && marsMagnitude! < 3.0,
                     "Mars magnitude \(marsMagnitude!) is outside expected range")
        
        // Test that sun returns a specific value and earthMoonBarycenter returns nil
        let sunMagnitude = SolarSystemBody.sun.apparentMagnitude(julianDay: date.julianDate)
        XCTAssertNotNil(sunMagnitude)
        XCTAssertEqual(sunMagnitude!, -26.74, accuracy: 0.01)
        
        XCTAssertNil(SolarSystemBody.earthMoonBarycenter.apparentMagnitude(julianDay: date.julianDate))
    }

    func testEarthCoodinate() throws {
        let formatter = ISO8601DateFormatter()
        let date = formatter.date(from: "2021-06-02T06:29:00-0600")!
        XCTAssertEqual(SolarSystemBody.earth.heliocentricEclipticCoordinate(julianDay: date.julianDate), SIMD3<Double>(-0.3150715723318, -0.9640605259254008, 5.0364834723560516e-05))
        XCTAssertEqual(length(SolarSystemBody.earth.heliocentricEclipticCoordinate(julianDay: date.julianDate)), 1.0, accuracy: 0.02)
    }
}

extension Date {
    public var julianDate: Double {
        appleZero + timeIntervalSinceReferenceDate * sec2day
    }
}
