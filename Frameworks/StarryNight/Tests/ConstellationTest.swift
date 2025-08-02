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
    
    private var starManager: StarManager!
    
    override func setUp() {
        super.setUp()
        do {
            starManager = try StarManager()
        } catch {
            XCTFail("Failed to initialize StarManager: \(error)")
        }
    }
    
    override func tearDown() {
        starManager = nil
        super.tearDown()
    }
    
    func testConstellationQuery() async {
        let iauQuery = await starManager.constellation(iau: "Tau")
        XCTAssertNotNil(iauQuery)
        let nameQuery = await starManager.constellation(named: "Orion")
        XCTAssertNotNil(nameQuery)
    }

    func testConnectionLinesLoading() async {
        let allConstellations = await starManager.allConstellations()
        // Performance test for constellation lines loading
        await measureAsync {
            for constellation in allConstellations {
                _ = await starManager.constellationLines(for: constellation)
            }
        }
    }
    
    private func measureAsync(_ block: () async throws -> Void) async {
        let startTime = CFAbsoluteTimeGetCurrent()
        try! await block()
        let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
        print("Time elapsed: \(timeElapsed) s.")
    }
}
