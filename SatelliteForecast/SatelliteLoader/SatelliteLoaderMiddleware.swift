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
    OutputActionType == AppAction,
    StateType == SatelliteLoaderState,
    Dependencies == SatelliteLoaderDependencies {

    static func satelliteLoader(
        _ satelliteLoader: SatelliteLoader
    ) -> MiddlewareReader<SatelliteLoaderDependencies, EffectMiddleware<SatelliteLoaderAction, AppAction, SatelliteLoaderState, SatelliteLoaderDependencies>> {
        EffectMiddleware<SatelliteLoaderAction, AppAction, SatelliteLoaderState, SatelliteLoaderDependencies>
        .onAction { (inputAction, dispatcher, getState) -> Effect<SatelliteLoaderDependencies, AppAction> in
            switch inputAction {
            case let .loadSatelliteCategory(category, calculatePass):
                return Effect(token: category) { context -> AnyPublisher<DispatchedAction<AppAction>, Never> in
                    func loadSatellitePublisher() -> AnyPublisher<DispatchedAction<AppAction>, Never> {
                        satelliteLoader.loadSatelliteCategoryPublisher(
                            category: category
                        )
                        .map { map -> DispatchedAction<AppAction> in
                            DispatchedAction(
                                .satelliteLoaderOutput(
                                    .loadedSatelliteInfo(
                                        category,
                                        map,
                                        calculatePass: calculatePass
                                    )
                                )
                            )
                        }
                        .catch { error in
                            Just(
                                DispatchedAction(
                                    .satelliteLoaderOutput(
                                        .failedLoadingTLEFile(category, error)
                                    )
                                )
                            )
                        }
                        .eraseToAnyPublisher()
                    }

                    if let result = getState().resources.info[category], let infoMap = result.successValue {
                        let mostRecentTLEAge = infoMap.map {
                            Date(julianDate: getState().currentDate).timeIntervalSince(Date(daysSince1950: $1.satellite.tle.t₀))
                        }
                        .min() ?? 0

                        if mostRecentTLEAge > context.dependencies.updateInterval {
                            logger.notice("Most recent TLE age \(mostRecentTLEAge) too old: updating.")
                            return loadSatellitePublisher()
                        }

                        logger.notice("Most recent TLE age \(mostRecentTLEAge) is new: skip update.")

                        return Empty<DispatchedAction<AppAction>, Never>(completeImmediately: true)
                                .eraseToAnyPublisher()
                    } else {
                        return loadSatellitePublisher()
                    }
                }
            }
        }
    }
}

extension MiddlewareReader where MiddlewareType == EffectMiddleware<SatelliteLoaderAction, AppAction, SatelliteLoaderState, SatelliteLoaderDependencies>, Dependencies == SatelliteLoaderDependencies {
    func lift() -> MiddlewareReader<SatelliteLoaderDependencies, LiftMiddleware<AppAction, AppAction, AppState, EffectMiddleware<SatelliteLoaderAction, AppAction, SatelliteLoaderState, SatelliteLoaderDependencies>>> {
        return lift(
            inputAction: \AppAction.satelliteLoader,
            state: SatelliteLoaderState.project(appState:)
        )
    }
}

extension EffectMiddleware where InputActionType == SatelliteLoaderOutput, OutputActionType == AllPassesViewAction, StateType == SatelliteLoaderState, Dependencies == Void {
    /// This middleware triggers `calculatePass` event after satellite has been loaded
    static var calculatePassAfterSatelliteLoader: EffectMiddleware<SatelliteLoaderOutput, AllPassesViewAction, SatelliteLoaderState, Void> {
        EffectMiddleware.onAction { action, dispatcher, getState in
            switch action {
            case .loadedSatelliteInfo(_, let satelliteInfoMap, let calculatePass):
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

    func lift() -> AnyMiddleware<AppAction, AppAction, AppState> {
        return lift(
            inputAction: \.satelliteLoaderOutput,
            outputAction: AppAction.allPassesView,
            state: SatelliteLoaderState.project(appState:)
        )
        .eraseToAnyMiddleware()
    }
}
