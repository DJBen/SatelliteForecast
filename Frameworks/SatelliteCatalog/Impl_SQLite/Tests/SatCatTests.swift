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
        let DB = try! Connection(Bundle.SatelliteCatalogImpl_SQLiteResourcesBundle.path(forResource: "satellites", ofType: "sqlite")!)

        let rows = try DB.prepare(SatCat.Table.tableName)
        for row in rows {
            _ = SatCat(row: row)
        }
    }
}

