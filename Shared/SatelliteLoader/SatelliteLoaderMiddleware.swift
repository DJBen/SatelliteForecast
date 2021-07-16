//
//  SatelliteLoaderMiddleware.swift
//  SatelliteForcast
//
//  Created by Ben Lu on 6/4/21.
//

import Foundation
import os
import BTree
import Combine
import CombineRex
import SatelliteKit
import SatelliteForcastCore
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

    static func satelliteLoader(_ satelliteLoader: SatelliteLoader) -> MiddlewareReader<SatelliteLoaderDependencies, EffectMiddleware<SatelliteLoaderAction, AppAction, SatelliteLoaderState, SatelliteLoaderDependencies>> {
        EffectMiddleware<SatelliteLoaderAction, AppAction, SatelliteLoaderState, SatelliteLoaderDependencies>
        .onAction { (inputAction, dispatcher, getState) -> Effect<SatelliteLoaderDependencies, AppAction> in
            switch inputAction {
            case let .loadSatelliteCategory(category, shouldCalculatePasses):
                return Effect(token: category) { context -> AnyPublisher<DispatchedAction<AppAction>, Never> in

                    func loadSatellitePublisher() -> AnyPublisher<DispatchedAction<AppAction>, Never> {
                        satelliteLoader.loadSatelliteCategoryPublisher(category: category)
                            .map { DispatchedAction<AppAction>(.satelliteLoader($0), dispatcher: dispatcher) }
                            .flatMap { action -> AnyPublisher<DispatchedAction<AppAction>, Never> in
                                if shouldCalculatePasses {
                                    return Just(action)
                                        .merge(with: Just(DispatchedAction<AppAction>(.allPassesView(.calculatePasses), dispatcher: dispatcher)))
                                        .eraseToAnyPublisher()
                                } else {
                                    return Just(action).eraseToAnyPublisher()
                                }
                            }
                            .eraseToAnyPublisher()
                    }

                    if let result = getState().info[category], let info = result.successValue {
                        let mostRecentTLEAge = info.map {
                            Date(julianDate: getState().referenceDate).timeIntervalSince(Date(daysSince1950: $1.satellite.tle.t₀))
                        }
                        .min() ?? 0

                        if mostRecentTLEAge > context.dependencies.updateInterval {
                            logger.notice("Most recent TLE age \(mostRecentTLEAge) too old: updating.")
                            return loadSatellitePublisher()
                        }

                        logger.notice("Most recent TLE age \(mostRecentTLEAge) is new: skip update.")

                        if shouldCalculatePasses {
                            return Just(DispatchedAction<AppAction>(.allPassesView(.calculatePasses), dispatcher: dispatcher))
                                .eraseToAnyPublisher()
                        }
                        return Empty<DispatchedAction<AppAction>, Never>()
                            .eraseToAnyPublisher()
                    }

                    return loadSatellitePublisher()
                }
            case .loadedSatelliteInfo(_, _):
                return .doNothing
            case .failedLoadingTLEFile(_, _):
                return .doNothing
            }
        }
    }
}
