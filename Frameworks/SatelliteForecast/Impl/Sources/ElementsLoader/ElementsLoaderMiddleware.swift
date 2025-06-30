//
//  ElementsLoaderMiddleware.swift
//  SatelliteForecastImpl
//
//  Created by Ben Lu on 6/4/21.
//

import Foundation
import os
import BTree
import Combine
@preconcurrency import CombineRex
@preconcurrency import SatelliteKit
import SatelliteForecast
import SatelliteCatalog

fileprivate let logger = Logger(subsystem: "io.djben.elementsLoader", category: "middleware")

public struct ElementsLoaderDependencies {
    public let elementLoader: ElementsLoader
    public let dateProvider: () -> Date
    public let updateInterval: TimeInterval

    public init(
        elementsLoader: ElementsLoader,
        dateProvider: @escaping () -> Date,
        updateInterval: TimeInterval = 6 * 60 * 60
    ) {
        self.elementLoader = elementsLoader
        self.dateProvider = dateProvider
        self.updateInterval = updateInterval
    }
}

public typealias ElementsLoaderEffectMiddleware = EffectMiddleware<ElementsLoaderAction, ElementsLoaderOutput, ElementsLoaderState, ElementsLoaderDependencies>

extension EffectMiddleware where
    InputActionType == ElementsLoaderAction,
    OutputActionType == ElementsLoaderOutput,
    StateType == ElementsLoaderState,
    Dependencies == ElementsLoaderDependencies {

    public static var elementsLoader: MiddlewareReader<ElementsLoaderDependencies, ElementsLoaderEffectMiddleware> {
        ElementsLoaderEffectMiddleware.onAction { (inputAction, dispatcher, getState) -> Effect<ElementsLoaderDependencies, ElementsLoaderOutput> in
            switch inputAction {
            case let .loadElements(category, fetchStrategy, selectNoradIndex, calculatePass):
                return Effect(token: category) { context -> AnyPublisher<DispatchedAction<ElementsLoaderOutput>, Never> in
                    func loadSatellitePublisher() -> AnyPublisher<DispatchedAction<ElementsLoaderOutput>, Never> {
                        context.dependencies.elementLoader.loadElementsPublisher(
                            category: category,
                            fetchStrategy: fetchStrategy
                        )
                        .map { map -> DispatchedAction<ElementsLoaderOutput> in
                            DispatchedAction(
                                .loadedSatelliteElements(
                                    category: category,
                                    satelliteInfo: map,
                                    selectNoradIndex: selectNoradIndex,
                                    calculatePass: calculatePass
                                )
                            )
                        }
                        .catch { error in
                            Just(
                                DispatchedAction(
                                    .failedLoadingElements(category: category, error: error)
                                )
                            )
                        }
                        .eraseToAnyPublisher()
                    }

                    let state = getState()

                    if let result = state.resources.info[category], let infoMap = result.content {
                        let julianDate = context.dependencies.dateProvider().julianDate + state.julianDateOffset
                        let mostRecentElementsAge = infoMap.map {
                            Date(julianDate: julianDate).timeIntervalSince(Date(daysSince1950: $1.elements.t₀))
                        }
                        .min() ?? 0

                        if mostRecentElementsAge > context.dependencies.updateInterval {
                            logger.notice("Most recent Elements age \(mostRecentElementsAge) too old: updating.")
                            return loadSatellitePublisher()
                        }

                        logger.notice("Most recent Elements age \(mostRecentElementsAge) is new: skip update.")

                        return Just<DispatchedAction<ElementsLoaderOutput>>(
                            DispatchedAction(
                                .loadedSatelliteElements(
                                    category: category,
                                    satelliteInfo: infoMap,
                                    selectNoradIndex: selectNoradIndex,
                                    calculatePass: calculatePass
                                )
                            )
                        )
                        .eraseToAnyPublisher()
                    } else {
                        return loadSatellitePublisher()
                    }
                }
            }
        }
    }
}
