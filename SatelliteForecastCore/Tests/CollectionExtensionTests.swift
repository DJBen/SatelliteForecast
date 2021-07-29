//
//  CollectionExtensionTests.swift
//  SatelliteForecastCore-Unit-Tests
//
//  Created by Ben Lu on 6/12/21.
//

import Foundation
import BTree
@testable import SatelliteForecastCore
import XCTest

class CollectionExtensionTests: XCTestCase {
    func testSplit() {
        let result = [10, 20, 30, 50, 60, 70, 90].split(shouldSplit: { $1 - $0 > 10 })
        XCTAssertEqual(result, [[10, 20, 30], [50, 60, 70], [90]])
    }

    func testSplitMap() {
        var map = BTree<Int, String>()
        map.insertOrReplace((10, "Haha"))
        map.insertOrReplace((20, "123"))
        map.insertOrReplace((40, "qwer"))
        map.insertOrReplace((50, "rtyu"))
        map.insertOrReplace((70, "poiu"))
        let result = map.split(shouldSplit: { $1.0 - $0.0 > 10 })
        let map1 = BTree<Int, String>([
            (10, "Haha"),
            (20, "123")
        ])
        let map2 = BTree<Int, String>([
            (40, "qwer"),
            (50, "rtyu")
        ])
        let map3 = BTree<Int, String>([
            (70, "poiu")
        ])
        XCTAssertTrue(result[0] == map1)
        XCTAssertTrue(result[1] == map2)
        XCTAssertTrue(result[2] == map3)
        XCTAssertEqual(result.count, 3)
    }
}
