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
        let observer = LatLonAlt(lat: -27.1570, lon: -109.4274, alt: 0)
        let sunEci = SolarSystemBody.sun.eci(julianDay: date.julianDate)
        XCTAssertEqual(sunEci, solarCel(julianDays: date.julianDate), accuracy: Vector(0.01, 0.015, 0.01))
        let sunAziEle = SolarSystemBody.sun.aziEle(julianDay: date.julianDate, observer: observer)
        let reference = azel(time: date, site: (observer.lat, observer.lon), cele: solarGeo(julianDays: date.julianDate))
        XCTAssertEqual(sunAziEle, reference, accuracy: AziEle(azim: 0.1, elev: 0.5))
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
