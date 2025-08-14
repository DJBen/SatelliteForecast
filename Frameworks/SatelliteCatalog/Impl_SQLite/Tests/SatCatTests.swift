//
//  SatCatTests.swift
//  SatelliteCatalog-Unit-Tests
//
//  Created by Ben Lu on 6/23/21.
//

import XCTest
import SatelliteCatalog
@testable import SatelliteCatalogImpl_SQLite
import SQLite

class SatCatTests: XCTestCase {
    func testReadingSatCat() throws {
        let DB = try! Connection(Bundle.module.path(forResource: "satellites", ofType: "sqlite")!)

        let rows = try DB.prepare(SatCat.Table.tableName)
        for row in rows {
            _ = try SatCat(row: row)
        }
    }
}

