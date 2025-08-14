/*╔══════════════════════════════════════════════════════════════════════════════════════════════════╗
  ║ AstroTests.swift                                                                                 ║
  ║                                                                                                  ║
  ║ Created by Gavin Eadie on Feb25/20        Copyright 2020 Ramsay Consulting. All rights reserved. ║
  ╚══════════════════════════════════════════════════════════════════════════════════════════════════╝*/

// swiftlint:disable comma

import XCTest
@testable import SatelliteKit

class AstroTests: XCTestCase {

    let JD = 2_458_965.464_745_4

    override func setUp() {    }

    override func tearDown() {    }

    func testAstro() {

        let topVectorA = eci2top(julianDays: 2458905.0,
                                 satCel: Vector(10000.0, 10000.0, 0.0),
                                 obsLLA: LatLonAlt(lat: 0.0, lon: 0.0, alt: 0.0))
        print(topVectorA)

        let topVectorB = cel2top(julianDays: 2458905.0,
                                 satCel: Vector(10000.0, 10000.0, 0.0),
                                 obsCel: geo2xyz(julianDays: 2458905.0,
                                                 geodetic: LatLonAlt(lat: 0.0, lon: 0.0, alt: 0.0)))
        print(topVectorB)

        let topVectorC = topPosition(julianDays: 2458905.0,
                                     satCel: Vector(10000.0, 10000.0, 0.0),
                                     obsLLA: LatLonAlt(lat: 0.0, lon: 0.0, alt: 0.0))
        print(topVectorC)

        XCTAssertTrue(true)

    }

    func testECI_GEO() {
        let geo = eci2geo(julianDays: JD, celestial: Vector(10000.0, 10000.0, 0.0))
        let eci = geo2eci(julianDays: JD, geodetic: geo)
        print(eci)
    }

    func testECI_TOP() {
        let top = eci2top(julianDays: JD, satCel: Vector(10000.0, 10000.0, 0.0),
                                          obsLLA: LatLonAlt(lat: 0.0, lon: 0.0, alt: 0.0))
//        let eci = top2eci(julianDays: JD, sar: geo)
        print(top)
    }

    func testAzEl() {
        let azEl = azel(time: Date(), site: (45.0, -90.0), cele: (0.0, 0.0))
        print(azEl)
    }

    func testSolarGeo() {
        let formatter = ISO8601DateFormatter()
        let (ra, dec) = solarGeo(julianDays: formatter.date(from: "2021-06-07T17:41:00-0600")!.julianDate)
        XCTAssertEqual(ra, hms2deg(hms: (5, 5, 31.83)), accuracy: 0.1)
        XCTAssertEqual(dec, 22.846, accuracy: 0.1)
    }
}
