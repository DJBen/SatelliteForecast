//
//  StarTest.swift
//  Graviton
//
//  Created by Ben Lu on 2/4/17.
//  Copyright © 2017 Ben Lu. All rights reserved.
//

import XCTest
@testable import StarryNight

final class StarTest: XCTestCase {
    func testStarQuery() {
        let starQuery = Star.magitudeLessThan(0)
        XCTAssertEqual(starQuery.count, 4)
        let s2Query = Star.hip(69673)
        XCTAssertNotNil(s2Query)
        XCTAssertEqual(s2Query!.identity.properName, "Arcturus")
        measure {
            _ = Star.magitudeLessThan(5.6)
        }
    }

    func testMassHrQueries() {
        measure {
            for i in 0..<10000 {
                _ = Star.hr(i)
            }
        }
    }
}
