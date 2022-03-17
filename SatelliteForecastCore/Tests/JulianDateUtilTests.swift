//
//  JulianDateUtilTests.swift
//  SatelliteForecastCore-Unit-Tests
//
//  Created by Ben Lu on 3/16/22.
//

import XCTest
@testable import SatelliteForecastCore

class JulianDateUtilTests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testRoundJulianDate() throws {
        let formatter = ISO8601DateFormatter()
        let date = formatter.date(from: "2021-06-02T12:35:45Z")!
        let rounded = formatter.string(from: Date(julianDate:  date.julianDate.roundJulianDate(.toMins(1))))
        XCTAssertEqual(rounded, "2021-06-02T12:36:00Z")
        let date2 = formatter.date(from: "2021-06-02T12:35:12Z")!
        let rounded2 = formatter.string(from: Date(julianDate:  date2.julianDate.roundJulianDate(.toMins(1))))
        XCTAssertEqual(rounded2, "2021-06-02T12:35:00Z")
    }

    func testRoundJulianDate_doubleError() throws {
        let formatter = ISO8601DateFormatter()
        let date = formatter.date(from: "2021-06-02T12:35:45Z")!
        let rounded = Date(julianDate:  date.julianDate.roundJulianDate(.toMins(1)))
        let date2 = formatter.date(from: "2021-06-02T12:36:12Z")!
        let rounded2 = Date(julianDate:  date2.julianDate.roundJulianDate(.toMins(1)))
        XCTAssertEqual(rounded, rounded2)
    }
}
