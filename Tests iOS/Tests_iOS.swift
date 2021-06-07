//
//  Tests_iOS.swift
//  Tests iOS
//
//  Created by Ben Lu on 5/28/21.
//

import XCTest

class Tests_iOS: XCTestCase {
    func testLaunchPerformance() throws {
        if #available(macOS 10.15, iOS 13.0, tvOS 13.0, *) {
            // This measures how long it takes to launch your application.
            measure(metrics: [XCTApplicationLaunchMetric()]) {
                XCUIApplication().launch()
            }
        }
    }
}
