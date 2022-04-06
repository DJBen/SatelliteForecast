//
//  ElementsTests.swift
//  SatelliteForecast-Unit-Tests
//
//  Created by Ben Lu on 6/12/21.
//

import XCTest
import SatelliteKit
@testable import SatelliteForecast

class ElementsTests: XCTestCase {

    override func setUpWithError() throws {
    }

    override func tearDownWithError() throws {
    }

    func testFindPass() throws {
        let elements = try! Elements(
            raw: """
            ISS (ZARYA)
            1 25544U 98067A   21152.11066515  .00000451  00000-0  16375-4 0  9992
            2 25544  51.6453  62.2423 0003364  52.3737  88.5313 15.48937685286109
            """
        )
        let satelliteInfo = SatelliteInfo(elements: elements)
        let formatter = ISO8601DateFormatter()
        let date = formatter.date(from: "2021-06-02T20:35:30+0800")!
        let observer = LatLonAlt(lat: 32.0669, lon: 118.8251, alt: 0)
        let coarseSnapshots = try! satelliteInfo.generateSnapshots(observer: observer, julianDateRange: date.julianDate...date.addingTimeInterval(800).julianDate)
        let passSnapshots = try! satelliteInfo.findPasses(
            observer: LatLonAlt(lat: 32.0669, lon: 118.8251, alt: 0),
            coarseSnapshots: coarseSnapshots
        )
    }
}
