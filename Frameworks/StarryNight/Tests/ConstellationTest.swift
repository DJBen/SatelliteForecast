//
//  ConstellationTest.swift
//  Graviton
//
//  Created by Sihao Lu on 3/4/17.
//  Copyright © 2017 Ben Lu. All rights reserved.
//

import XCTest
@testable import StarryNight

final class ConstellationTest: XCTestCase {
    func testConstellationQuery() {
        let iauQuery = Constellation.iau("Tau")
        XCTAssertNotNil(iauQuery)
        let nameQuery = Constellation.named("Orion")
        XCTAssertNotNil(nameQuery)
    }

    func testConnectionLinesLoading() {
        measure {
            Constellation.all.forEach { (constellation) in
                _ = constellation.connectionLines
            }
        }
    }
}
