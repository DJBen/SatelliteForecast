//
//  QSMagTests.swift
//  QSMag-Unit-Tests
//
//  Created by Ben Lu on 3/7/22.
//

import XCTest
import QSMag

class QSMagTests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testLoadLocalData() throws {
        let qsMags = QSMag.loadLocalData()
        let iss = try! XCTUnwrap(qsMags[25544])
        XCTAssertEqual(iss.name, "ISS")
        XCTAssertEqual(iss.magnitude, -2.5)
        XCTAssertEqual(iss.rcs, 399)

        let cz5rb = try! XCTUnwrap(qsMags[44911])
        XCTAssertEqual(cz5rb.name, "CZ-5 R/B")
        XCTAssertNil(cz5rb.magnitude)
        XCTAssertNil(cz5rb.rcs)

        let unknown = try! XCTUnwrap(qsMags[90084])
        XCTAssertEqual(unknown.name, "Unknwn 9O0DC57")
        XCTAssertEqual(unknown.magnitude, 4.0)
        XCTAssertNil(unknown.rcs)
    }

    func testPerformance() throws {
        // This is an example of a performance test case.
        self.measure {
            _ = QSMag.loadLocalData()
        }
    }

}
