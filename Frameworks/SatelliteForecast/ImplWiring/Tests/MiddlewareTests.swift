//
//  MiddlewareTests.swift
//  SatelliteForecastTests
//
//  Created by Ben Lu on 2/16/22.
//

import XCTest
@preconcurrency import CombineRex
import TestingExtensions
import SatelliteForecast
import SatelliteForecastImpl
import SatelliteForecastImplWiring

class MiddlewareTests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func test_satelliteOverviewToElementLoader_loadSatelliteOfSpecialInterest() throws {
        assert(
            initialValue: AppState(),
            reducer: .identity,
            middleware: EffectMiddleware.satelliteOverviewToElementLoader.lift(),
            steps: {
                Send(
                    action: .satelliteOverview(
                        .loadSatelliteOfSpecialInterest(.init(noradIndex: 0), julianDateRange: 1...2, observer: nil)
                    )
                )

                Receive { action -> Bool in
                    guard case .singleSatelliteWrappingView(
                        .loadSingleSatellite(
                            .init(
                                selectedNoradIndex: 0,
                                julianDateRange: 1...2,
                                observer: nil
                            )
                        )
                    ) = action else {
                        return false
                    }
                    return true
                }
            }
        )
    }
}
