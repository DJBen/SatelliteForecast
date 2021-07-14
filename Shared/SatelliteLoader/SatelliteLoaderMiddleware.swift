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
    InputActionType == SatelliteLoaderInputAction,
    OutputActionType == SatelliteLoaderOutputAction,
    StateType == SatelliteLoaderState,
    Dependencies == SatelliteLoaderDependencies {

    static var satelliteLoader: MiddlewareReader<SatelliteLoaderDependencies, EffectMiddleware<SatelliteLoaderInputAction, SatelliteLoaderOutputAction, SatelliteLoaderState, SatelliteLoaderDependencies>> {
        EffectMiddleware<SatelliteLoaderInputAction, SatelliteLoaderOutputAction, SatelliteLoaderState, SatelliteLoaderDependencies>
            .onAction { (inputAction, dispatcher, getState) -> Effect<SatelliteLoaderDependencies, SatelliteLoaderOutputAction> in
            switch inputAction {
            case let .loadSatelliteCategory(category):
                return Effect(token: category) { context -> AnyPublisher<DispatchedAction<SatelliteLoaderOutputAction>, Never> in
                    if let result = getState().info[category], let info = result.successValue {
                        let averageTLEAge = info.map {
                            Date(julianDate: getState().referenceDate).timeIntervalSince(Date(daysSince1950: $1.satellite.tle.t₀))
                        }
                        .reduce(0, +) / Double(info.count)

                        if averageTLEAge > context.dependencies.updateInterval {
                            logger.notice("Avg TLE age \(averageTLEAge) too old: updating.")
                            return SatelliteLoader.loadSatelliteCategoryPublisher(category: category)
                                .map { DispatchedAction<SatelliteLoaderOutputAction>($0, dispatcher: dispatcher) }
                                .eraseToAnyPublisher()
                        }

                        logger.notice("Avg TLE age \(averageTLEAge) is new: skip update.")
                        return Empty<DispatchedAction<SatelliteLoaderOutputAction>, Never>()
                            .eraseToAnyPublisher()
                    }

                    return SatelliteLoader.loadSatelliteCategoryPublisher(category: category)
                        .map { DispatchedAction<SatelliteLoaderOutputAction>($0, dispatcher: dispatcher) }
                        .eraseToAnyPublisher()
                }
            }
        }
    }
}
