//
//  SkyChartUtilsTests.swift
//  SatelliteForecastImpl-Unit-Tests
//
//  Created by Ben Lu on 11/22/22.
//

import XCTest
import SatelliteKit
@testable import SatelliteForecastImpl

final class SkyChartUtilsTests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testPointConversion() throws {
        let aziEle = AziEle(azim: 60, elev: 30)
        let rect = CGRect(x: 0, y: 0, width: 100, height: 100)
        let point = SkyChartUtils.point(at: aziEle, rect: rect)
        let aziEleResult = SkyChartUtils.aziEle(at: point, in: rect)
        XCTAssertEqual(aziEle.azim, aziEleResult.azim, accuracy: 1e-6)
        XCTAssertEqual(aziEle.elev, aziEleResult.elev, accuracy: 1e-6)
    }
}
