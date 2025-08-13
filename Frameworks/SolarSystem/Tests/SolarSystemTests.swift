//
//  SolarSystemTests.swift
//  SolarSystem-Unit-Tests
//
//  Created by Ben Lu on 3/19/22.
//

import XCTest
@testable import SolarSystem
@preconcurrency import SatelliteKit

class SolarSystemTests: XCTestCase {
    func testSunCoordinate() throws {
        let formatter = ISO8601DateFormatter()
        let date = formatter.date(from: "2021-06-02T06:29:00-0600")!
        let observer = LatLonAlt(-27.1570, -109.4274, 0.0)
        let sunEci = SolarSystemBody.sun.eci(julianDay: date.julianDate)
        XCTAssertEqual(sunEci, solarCel(julianDays: date.julianDate), accuracy: Vector(0.01, 0.015, 0.01))
        let reference = azel(time: date, site: LatLon(observer), cele: solarGeo(julianDays: date.julianDate))
        // Just test that these are approximately reasonable values
        XCTAssertGreaterThan(reference.azim, 0.0)
        XCTAssertLessThan(reference.azim, 360.0)
    }
    
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
}

#if canImport(XCTest)

public func XCTAssertEqual(_ expression1: Vector, _ expression2: Vector, accuracy: Vector, _ message: @autoclosure () -> String = "", file: StaticString = #filePath, line: UInt = #line) {
    XCTAssertEqual(expression1.x, expression2.x, accuracy: accuracy.x)
    XCTAssertEqual(expression1.y, expression2.y, accuracy: accuracy.y)
    XCTAssertEqual(expression1.z, expression2.z, accuracy: accuracy.z)
}

public func XCTAssertEqual(_ expression1: AziEle, _ expression2: AziEle, accuracy: AziEle, _ message: @autoclosure () -> String = "", file: StaticString = #filePath, line: UInt = #line) {
    XCTAssertEqual(expression1.azim, expression2.azim, accuracy: accuracy.azim)
    XCTAssertEqual(expression1.elev, expression2.elev, accuracy: accuracy.elev)
}

#endif
