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
    
    private var starManager: StarManager!
    
    override func setUp() {
        super.setUp()
        do {
            starManager = try StarManager()
        } catch {
            XCTFail("Failed to initialize StarManager: \(error)")
        }
    }
    
    func testStarQuery() async throws {
        let starQuery = await starManager.brightestStars()
        XCTAssertEqual(starQuery.count, 300)
        
        // // Search for Arcturus by HIP number
        // let arcturus = await starManager.searchStars(matching: "HIP 69673")
        // XCTAssertFalse(arcturus.isEmpty)
        // let arcturusWithInfoResult = await starManager.starWithInfo(id: arcturus.first!.id)
        // let arcturusWithInfo = try XCTUnwrap(arcturusWithInfoResult)
        // XCTAssertEqual(try XCTUnwrap(arcturusWithInfo.info).properName, "Arcturus")
    }
}
