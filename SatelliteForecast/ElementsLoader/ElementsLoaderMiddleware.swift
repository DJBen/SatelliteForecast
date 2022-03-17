//
//  ElementsLoaderMiddleware.swift
//  SatelliteForecast
//
//  Created by Ben Lu on 6/4/21.
//

import Foundation
import os
import BTree
import Combine
import CombineRex
import SatelliteKit
import SatelliteForecastCore
import SatelliteCatalog

fileprivate let logger = Logger(subsystem: "io.djben.elementsLoader", category: "middleware")

struct ElementsLoaderDependencies {
    let updateInterval: TimeInterval = 4 * 60 * 60
}

extension EffectMiddleware where
    InputActionType == ElementsLoaderAction,
    OutputActionType == ElementsLoaderOutput,
    StateType == ElementsLoaderState,
    Dependencies == ElementsLoaderDependencies {

    static func elementsLoader(
        _ elementsLoader: ElementsLoader
    ) -> MiddlewareReader<ElementsLoaderDependencies, EffectMiddleware<ElementsLoaderAction, ElementsLoaderOutput, ElementsLoaderState, ElementsLoaderDependencies>> {
        EffectMiddleware<ElementsLoaderAction, ElementsLoaderOutput, ElementsLoaderState, ElementsLoaderDependencies>
        .onAction { (inputAction, dispatcher, getState) -> Effect<ElementsLoaderDependencies, ElementsLoaderOutput> in
            switch inputAction {
            case let .loadElements(category, selectSpecialNoradIndex, selectNoradIndex, calculatePass):
                return Effect(token: category) { context -> AnyPublisher<DispatchedAction<ElementsLoaderOutput>, Never> in
                    func loadSatellitePublisher() -> AnyPublisher<DispatchedAction<ElementsLoaderOutput>, Never> {
                        elementsLoader.loadElementsPublisher(
                            category: category
                        )
                        .map { map -> DispatchedAction<ElementsLoaderOutput> in
                            DispatchedAction(
                                .loadedSatelliteElements(
                                    category: category,
                                    satelliteInfo: map,
                                    selectSpecialNoradIndex: selectSpecialNoradIndex,
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

                    if let result = getState().resources.info[category], let infoMap = result.content {
                        let mostRecentElementsAge = infoMap.map {
                            Date(julianDate: getState().currentDate).timeIntervalSince(Date(daysSince1950: $1.elements.t₀))
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

extension EffectMiddleware where InputActionType == ElementsLoaderOutput, OutputActionType == SatelliteOverviewViewAction, StateType == ElementsLoaderState, Dependencies == Void {
    /// This middleware triggers `calculatePass` event after satellite has been loaded
    static var selectSpecialSatelliteAfterElementsLoader: EffectMiddleware<ElementsLoaderOutput, SatelliteOverviewViewAction, ElementsLoaderState, Void> {
        EffectMiddleware.onAction { action, dispatcher, getState in
            switch action {
            case .loadedSatelliteElements(_, _, let selectSpecialNoradIndex, _, _):
                guard let selectSpecialNoradIndex = selectSpecialNoradIndex else {
                    return .doNothing
                }

                return .just(
                    .selectSpecialSatellite(
                        SatelliteOverviewViewAction.SelectSpecialSatelliteParams(
                            noradIndex: selectSpecialNoradIndex.noradIndex,
                            julianDateRange: selectSpecialNoradIndex.dateRange,
                            observer: selectSpecialNoradIndex.observer
                        )
                    ),
                    from: dispatcher
                )

            case .failedLoadingElements(_, _):
                return .doNothing
            }
        }
    }
}

extension EffectMiddleware where InputActionType == ElementsLoaderOutput, OutputActionType == SatelliteListViewAction, StateType == ElementsLoaderState, Dependencies == Void {
    /// This middleware triggers `calculatePass` event after satellite has been loaded
    static var selectSatelliteAfterElementsLoader: EffectMiddleware<ElementsLoaderOutput, SatelliteListViewAction, ElementsLoaderState, Void> {
        EffectMiddleware.onAction { action, dispatcher, getState in
            switch action {
            case .loadedSatelliteElements(_, let satelliteInfoMap, _, let selectNoradIndex, _):
                guard let selectNoradIndex = selectNoradIndex, let satelliteInfo = satelliteInfoMap[selectNoradIndex.noradIndex] else {
                    return .doNothing
                }

                return .just(
                    .selectSatellite(
                        SatelliteListViewAction.SelectSatelliteParams(
                            noradIndex: selectNoradIndex.noradIndex,
                            satelliteInfo: satelliteInfo,
                            julianDateRange: selectNoradIndex.dateRange,
                            observer: selectNoradIndex.observer
                        )
                    ),
                    from: dispatcher
                )

            case .failedLoadingElements(_, _):
                return .doNothing
            }
        }
    }
}

extension EffectMiddleware where InputActionType == ElementsLoaderOutput, OutputActionType == AllPassesViewAction, StateType == ElementsLoaderState, Dependencies == Void {
    /// This middleware triggers `calculatePass` event after satellite has been loaded
    static var calculatePassAfterElementsLoader: EffectMiddleware<ElementsLoaderOutput, AllPassesViewAction, ElementsLoaderState, Void> {
        EffectMiddleware.onAction { action, dispatcher, getState in
            switch action {
            case .loadedSatelliteElements(_, let satelliteInfoMap, _, _, let calculatePass):
                guard let calculatePass = calculatePass, let satelliteInfo = satelliteInfoMap[calculatePass.noradIndex] else {
                    return .doNothing
                }

                return .just(
                    .calculatePasses(
                        AllPassesViewAction.CalculatePassesParams(
                            selectedNoradIndex: calculatePass.noradIndex,
                            satelliteInfo: satelliteInfo,
                            julianDateRange: calculatePass.dateRange,
                            observer: calculatePass.observer
                        )
                    ),
                    from: dispatcher
                )

            case .failedLoadingElements(_, _):
                return .doNothing
            }
        }
    }
}
