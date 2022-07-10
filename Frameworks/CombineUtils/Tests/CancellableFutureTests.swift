//
//  CancellableFutureTests.swift
//  SatelliteForecastTests
//
//  Created by Ben Lu on 2/15/22.
//

import XCTest
import Combine
@testable import CombineUtils

class CancellableFutureTests: XCTestCase {

    private var cancellable: AnyCancellable?

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testCancellableFuture_normal() throws {
        var values: [Int] = []
        let exp = expectation(description: "CancellableFuture should complete its job")
        cancellable = CancellableFuture { promise, cancelRef in
            if cancelRef.isCancelled {
                return
            }
            for i in 0..<5 where !cancelRef.isCancelled {
                values.append(i)
                Thread.sleep(forTimeInterval: 0.05)
            }
            exp.fulfill()
        }
        .sink(receiveValue: {})

        waitForExpectations(timeout: 1, handler: nil)

        XCTAssertEqual(values, Array(0..<5))
    }

    func testCancellableFuture_cancel() throws {
        var values: [Int] = []
        let exp = expectation(description: "CancellableFuture should complete its job")
        cancellable = CancellableFuture { promise, cancelRef in
            DispatchQueue.main.async {
                if cancelRef.isCancelled {
                    return
                }
                for i in 0..<5 where !cancelRef.isCancelled {
                    values.append(i)
                    print("append \(i)")
                    Thread.sleep(forTimeInterval: 0.05)
                }
                exp.fulfill()
            }
        }
        .sink(receiveValue: {})

        DispatchQueue(label: "").asyncAfter(deadline: .now() + .milliseconds(120)) { [weak self] in
            print("cancel")
            self?.cancellable?.cancel()
        }

        waitForExpectations(timeout: 1, handler: nil)

        XCTAssertEqual(values, Array(0..<3))
    }
}
