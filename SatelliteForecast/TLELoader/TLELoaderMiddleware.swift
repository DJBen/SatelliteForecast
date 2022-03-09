//
//  TLELoaderMiddleware.swift
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

fileprivate let logger = Logger(subsystem: "io.djben.tleLoader", category: "middleware")

struct TLELoaderDependencies {
    let updateInterval: TimeInterval = 4 * 60 * 60
}

extension EffectMiddleware where
    InputActionType == TLELoaderAction,
    OutputActionType == TLELoaderOutput,
    StateType == TLELoaderState,
    Dependencies == TLELoaderDependencies {

    static func tleLoader(
        _ tleLoader: TLELoader
    ) -> MiddlewareReader<TLELoaderDependencies, EffectMiddleware<TLELoaderAction, TLELoaderOutput, TLELoaderState, TLELoaderDependencies>> {
        EffectMiddleware<TLELoaderAction, TLELoaderOutput, TLELoaderState, TLELoaderDependencies>
        .onAction { (inputAction, dispatcher, getState) -> Effect<TLELoaderDependencies, TLELoaderOutput> in
            switch inputAction {
            case let .loadSatelliteTLEs(category, selectSpecialNoradIndex, selectNoradIndex, calculatePass):
                return Effect(token: category) { context -> AnyPublisher<DispatchedAction<TLELoaderOutput>, Never> in
                    func loadSatellitePublisher() -> AnyPublisher<DispatchedAction<TLELoaderOutput>, Never> {
                        tleLoader.loadSatelliteTLEsPublisher(
                            category: category
                        )
                        .map { map -> DispatchedAction<TLELoaderOutput> in
                            DispatchedAction(
                                .loadedSatelliteTLEs(
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
                                    .failedLoadingTLEFile(category: category, error: error)
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

                        return Just<DispatchedAction<TLELoaderOutput>>(
                            DispatchedAction(
                                .loadedSatelliteTLEs(
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

extension EffectMiddleware where InputActionType == TLELoaderOutput, OutputActionType == SatelliteOverviewViewAction, StateType == TLELoaderState, Dependencies == Void {
    /// This middleware triggers `calculatePass` event after satellite has been loaded
    static var selectSpecialSatelliteAfterTLELoader: EffectMiddleware<TLELoaderOutput, SatelliteOverviewViewAction, TLELoaderState, Void> {
        EffectMiddleware.onAction { action, dispatcher, getState in
            switch action {
            case .loadedSatelliteTLEs(_, _, let selectSpecialNoradIndex, _, _):
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

extension EffectMiddleware where InputActionType == TLELoaderOutput, OutputActionType == SatelliteListViewAction, StateType == TLELoaderState, Dependencies == Void {
    /// This middleware triggers `calculatePass` event after satellite has been loaded
    static var selectSatelliteAfterTLELoader: EffectMiddleware<TLELoaderOutput, SatelliteListViewAction, TLELoaderState, Void> {
        EffectMiddleware.onAction { action, dispatcher, getState in
            switch action {
            case .loadedSatelliteTLEs(_, let satelliteInfoMap, _, let selectNoradIndex, _):
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

extension EffectMiddleware where InputActionType == TLELoaderOutput, OutputActionType == AllPassesViewAction, StateType == TLELoaderState, Dependencies == Void {
    /// This middleware triggers `calculatePass` event after satellite has been loaded
    static var calculatePassAfterTLELoader: EffectMiddleware<TLELoaderOutput, AllPassesViewAction, TLELoaderState, Void> {
        EffectMiddleware.onAction { action, dispatcher, getState in
            switch action {
            case .loadedSatelliteTLEs(_, let satelliteInfoMap, _, _, let calculatePass):
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

            case .failedLoadingTLEFile(_, _):
                return .doNothing
            }
        }
    }
}
