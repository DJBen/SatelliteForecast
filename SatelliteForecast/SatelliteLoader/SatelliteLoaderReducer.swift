//
//  SatelliteLoaderReducer.swift
//  SatelliteForecast
//
//  Created by Ben Lu on 6/4/21.
//

import Foundation
import os
import SwiftRex

fileprivate let logger = Logger(subsystem: "io.djben.satelliteLoader", category: "reducer")

extension Reducer where ActionType == SatelliteLoaderAction, StateType == SatelliteLoaderState {
    static let satelliteLoaderReducer = Reducer.reduce { action, state in
        switch action {
        case .loadSatelliteCategory(let category, _, _, _):
            state.resources.info[category] = .loading
        }
    }
}

extension Reducer where ActionType == SatelliteLoaderOutput, StateType == SatelliteLoaderState {
    static let satelliteLoaderOutputReducer = Reducer.reduce { action, state in
        switch action {
        case let .loadedSatelliteInfo(category, info, _, _, _):
            state.resources.info[category] = .loaded(info)
            logger.notice("Loaded \(info.count) TLE entries")
        case let .failedLoadingTLEFile(category, error):
            state.resources.info[category] = .failed(error)
            logger.error("Failed loading TLE for category \(String(describing: category)): \(String(describing: error))")
            break
        }
    }
}
