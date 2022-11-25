//
//  ElementsLoaderTests.swift
//  SatelliteForecastImpl-Unit-Tests
//
//  Created by Ben Lu on 4/2/22.
//

import XCTest
import BTree
import Combine
import CombineRex
import TestingExtensions
import SatelliteForecast
@testable import SatelliteForecastImpl

class ElementsLoaderTests: XCTestCase {
    enum Action: Equatable {
        case elementsLoaderAction(ElementsLoaderAction)
        case elementsLoaderOutput(ElementsLoaderOutput)
    }

    struct MockError: Error, Equatable {

    }

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testElementsLoaderMiddleware_loadElements() throws {
        assert(
            initialValue: ElementsLoaderState(),
            reducer: .identity,
            middleware: EffectMiddleware.elementsLoader.inject(
                ElementsLoaderDependencies(
                    elementsLoader: FakeElementsLoader(
                        result: .success([:])
                    ),
                    dateProvider: { Date(timeIntervalSince1950: 0) }
                )
            )
            .lift(
                inputAction: {
                    guard case let .elementsLoaderAction(value) = $0 else { return nil }
                    return value
                },
                outputAction: Action.elementsLoaderOutput
            ),
            steps: {
                Send(
                    action: .elementsLoaderAction(
                        .loadElements(
                            category: .active,
                            fetchStrategy: .onlineFirst,
                            selectSpecialNoradIndex: nil,
                            selectNoradIndex: nil,
                            calculatePass: nil
                        )
                    )
                )
                Receive(
                    action: Action.elementsLoaderOutput(
                        .loadedSatelliteElements(
                            category: .active,
                            satelliteInfo: [:],
                            selectSpecialNoradIndex: nil,
                            selectNoradIndex: nil,
                            calculatePass: nil
                        )
                    )
                )
            }
        )

        assert(
            initialValue: ElementsLoaderState(),
            reducer: .identity,
            middleware: EffectMiddleware.elementsLoader.inject(
                ElementsLoaderDependencies(
                    elementsLoader: FakeElementsLoader(
                        result: .failure(.other(MockError()))
                    ),
                    dateProvider: { Date(timeIntervalSince1950: 0) }
                )
            )
            .lift(
                inputAction: {
                    guard case let .elementsLoaderAction(value) = $0 else { return nil }
                    return value
                },
                outputAction: Action.elementsLoaderOutput
            ),
            steps: {
                Send(
                    action: .elementsLoaderAction(
                        .loadElements(
                            category: .active,
                            fetchStrategy: .onlineFirst,
                            selectSpecialNoradIndex: nil,
                            selectNoradIndex: nil,
                            calculatePass: nil
                        )
                    )
                )
                Receive(
                    action: Action.elementsLoaderOutput(
                        .failedLoadingElements(
                            category: .active,
                            error: .other(MockError())
                        )
                    )
                )
            }
        )
    }
}

class FakeElementsLoader: ElementsLoader {
    let result: Result<Map<UInt, SatelliteInfo>, ElementsLoaderError>

    init(result: Result<Map<UInt, SatelliteInfo>, ElementsLoaderError>) {
        self.result = result
    }

    func loadElementsPublisher(
        category: SatelliteCategory,
        fetchStrategy: FetchStrategy
    ) -> AnyPublisher<Map<UInt, SatelliteInfo>, ElementsLoaderError> {
        result.publisher.eraseToAnyPublisher()
    }
}
