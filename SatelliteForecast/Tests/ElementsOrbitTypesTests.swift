//
//  ElementsOrbitTypesTests.swift
//  SatelliteForecast-Unit-Tests
//
//  Created by Ben Lu on 3/8/22.
//

import XCTest
import SatelliteKit
@testable import SatelliteForecast

class ElementsOrbitTypesTests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testOrbitTypes() throws {
        let elements = try! Elements(
            raw: """
            ISS (ZARYA)
            1 25544U 98067A   21152.11066515  .00000451  00000-0  16375-4 0  9992
            2 25544  51.6453  62.2423 0003364  52.3737  88.5313 15.48937685286109
            """
        )

        XCTAssertEqual(elements.orbitTypeByAltitude, .leo)

        let elements2 = try! Elements(
            raw: """
            COSMOS 2520
            1 42907U 17046A   22066.68790832  .00000131  00000+0  00000+0 0  9992
            2 42907   0.0303 124.3109 0000375 188.8667 144.8316  1.00274699 16720
            """
        )

        XCTAssertEqual(elements2.orbitTypeByAltitude, .geo)

        let elements3 = try! Elements(
            raw: """
            MOLNIYA 2-9
            1 07276U 74026A   21154.36625011 -.00000128  00000-0  00000-0 0  9990
            2 07276  64.2122 283.1177 6670908 285.3565  14.2908  2.45094844240000
            """
        )

        XCTAssertEqual(elements3.orbitTypeByAltitude, .meo)
    }
}
