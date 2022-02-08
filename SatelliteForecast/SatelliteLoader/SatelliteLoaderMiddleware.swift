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
            case let .loadSatelliteCategory(category, onCompletion):
                return Effect(token: category) { context -> AnyPublisher<DispatchedAction<AppAction>, Never> in
                    func loadSatellitePublisher() -> AnyPublisher<DispatchedAction<AppAction>, Never> {
                        satelliteLoader.loadSatelliteCategoryPublisher(category: category)
                            .flatMap { map -> AnyPublisher<DispatchedAction<AppAction>, Never> in
                                if let completionAction = onCompletion(map) {
                                    return Just(DispatchedAction(.satelliteLoaderOutput(.loadedSatelliteInfo(category, map))))
                                        .merge(with: Just(DispatchedAction(completionAction)))
                                        .eraseToAnyPublisher()
                                } else {
                                    return Just(DispatchedAction(.satelliteLoaderOutput(.loadedSatelliteInfo(category, map))))
                                        .eraseToAnyPublisher()
                                }
                            }
                            .catch { error in
                                Just(DispatchedAction(.satelliteLoaderOutput(.failedLoadingTLEFile(category, error))))
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

                        if let completionAction = onCompletion(infoMap) {
                            return Just(DispatchedAction(completionAction))
                                .eraseToAnyPublisher()
                        } else {
                            return Empty<DispatchedAction<AppAction>, Never>(completeImmediately: true)
                                .eraseToAnyPublisher()
                        }
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
