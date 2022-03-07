//
//  SatelliteLoaderMiddleware.swift
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

fileprivate let logger = Logger(subsystem: "io.djben.satelliteLoader", category: "middleware")

struct SatelliteLoaderDependencies {
    let updateInterval: TimeInterval = 4 * 60 * 60
}

extension EffectMiddleware where
    InputActionType == SatelliteLoaderAction,
    OutputActionType == SatelliteLoaderOutput,
    StateType == SatelliteLoaderState,
    Dependencies == SatelliteLoaderDependencies {

    static func satelliteLoader(
        _ satelliteLoader: SatelliteLoader
    ) -> MiddlewareReader<SatelliteLoaderDependencies, EffectMiddleware<SatelliteLoaderAction, SatelliteLoaderOutput, SatelliteLoaderState, SatelliteLoaderDependencies>> {
        EffectMiddleware<SatelliteLoaderAction, SatelliteLoaderOutput, SatelliteLoaderState, SatelliteLoaderDependencies>
        .onAction { (inputAction, dispatcher, getState) -> Effect<SatelliteLoaderDependencies, SatelliteLoaderOutput> in
            switch inputAction {
            case let .loadSatelliteCategory(category, selectSpecialNoradIndex, selectNoradIndex, calculatePass):
                return Effect(token: category) { context -> AnyPublisher<DispatchedAction<SatelliteLoaderOutput>, Never> in
                    func loadSatellitePublisher() -> AnyPublisher<DispatchedAction<SatelliteLoaderOutput>, Never> {
                        satelliteLoader.loadSatelliteCategoryPublisher(
                            category: category
                        )
                        .map { map -> DispatchedAction<SatelliteLoaderOutput> in
                            DispatchedAction(
                                .loadedSatelliteInfo(
                                    category,
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
                                    .failedLoadingTLEFile(category, error)
                                )
                            )
                        }
                        .eraseToAnyPublisher()
                    }

                    if let result = getState().resources.info[category], let infoMap = result.content {
                        let mostRecentTLEAge = infoMap.map {
                            Date(julianDate: getState().currentDate).timeIntervalSince(Date(daysSince1950: $1.tle.t₀))
                        }
                        .min() ?? 0

                        if mostRecentTLEAge > context.dependencies.updateInterval {
                            logger.notice("Most recent TLE age \(mostRecentTLEAge) too old: updating.")
                            return loadSatellitePublisher()
                        }

                        logger.notice("Most recent TLE age \(mostRecentTLEAge) is new: skip update.")

                        return Just<DispatchedAction<SatelliteLoaderOutput>>(
                            DispatchedAction(
                                .loadedSatelliteInfo(
                                    category,
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

extension EffectMiddleware where InputActionType == SatelliteLoaderOutput, OutputActionType == SatelliteOverviewViewAction, StateType == SatelliteLoaderState, Dependencies == Void {
    /// This middleware triggers `calculatePass` event after satellite has been loaded
    static var selectSpecialSatelliteAfterSatelliteLoader: EffectMiddleware<SatelliteLoaderOutput, SatelliteOverviewViewAction, SatelliteLoaderState, Void> {
        EffectMiddleware.onAction { action, dispatcher, getState in
            switch action {
            case .loadedSatelliteInfo(_, _, let selectSpecialNoradIndex, _, _):
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

            case .failedLoadingTLEFile(_, _):
                return .doNothing
            }
        }
    }
}

extension EffectMiddleware where InputActionType == SatelliteLoaderOutput, OutputActionType == SatelliteListViewAction, StateType == SatelliteLoaderState, Dependencies == Void {
    /// This middleware triggers `calculatePass` event after satellite has been loaded
    static var selectSatelliteAfterSatelliteLoader: EffectMiddleware<SatelliteLoaderOutput, SatelliteListViewAction, SatelliteLoaderState, Void> {
        EffectMiddleware.onAction { action, dispatcher, getState in
            switch action {
            case .loadedSatelliteInfo(_, let satelliteInfoMap, _, let selectNoradIndex, _):
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

            case .failedLoadingTLEFile(_, _):
                return .doNothing
            }
        }
    }
}

extension EffectMiddleware where InputActionType == SatelliteLoaderOutput, OutputActionType == AllPassesViewAction, StateType == SatelliteLoaderState, Dependencies == Void {
    /// This middleware triggers `calculatePass` event after satellite has been loaded
    static var calculatePassAfterSatelliteLoader: EffectMiddleware<SatelliteLoaderOutput, AllPassesViewAction, SatelliteLoaderState, Void> {
        EffectMiddleware.onAction { action, dispatcher, getState in
            switch action {
            case .loadedSatelliteInfo(_, let satelliteInfoMap, _, _, let calculatePass):
                guard let calculatePass = calculatePass, let satelliteInfo = satelliteInfoMap[calculatePass.noradID] else {
                    return .doNothing
                }

                return .just(
                    .calculatePasses(
                        AllPassesViewAction.CalculatePassesParams(
                            selectedNoradIndex: calculatePass.noradID,
                            satelliteInfo: satelliteInfo,
                            julianDateRange: calculatePass.dateRange,
                            observer: calculatePass.observer
                        )
                    ),
                    from: dispatcher
                )

            case .failedLoadingTLEFile(_, _):
                return .doNothing
            }
        }
    }
}
