//
//  UCSSatTests.swift
//  SatelliteCatalog-Unit-Tests
//
//  Created by Ben Lu on 6/24/21.
//

import XCTest
import SatelliteCatalog
@testable import SatelliteCatalogImpl_SQLite
import SQLite

class UCSSatTests: XCTestCase {
    func testReadingUSCSat() throws {
        let DB = try! Connection(Bundle.SatelliteCatalogImpl_SQLiteResourcesBundle.path(forResource: "satellites", ofType: "sqlite")!)

        let rows = try DB.prepare(UCSSat.Table.tableName)
        for row in rows {
            _ = UCSSat(row: row)
        }
    }

    func testDateConversation() throws {
        let sat = try XCTUnwrap(UCSSat.with(noradCatID: 47302))
        let formatter = DateFormatter()
        formatter.dateFormat = "YYYY-MM-dd"
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        XCTAssertEqual(sat.dateOfLaunch, formatter.date(from: "2020-12-27")!)
    }
}
