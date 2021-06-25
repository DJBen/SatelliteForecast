//
//  SatelliteLoaderReducer.swift
//  SatelliteForcast
//
//  Created by Ben Lu on 6/4/21.
//

import Foundation
import os
import SwiftRex

fileprivate let logger = Logger(subsystem: "io.djben.satelliteLoader", category: "reducer")

extension Reducer where ActionType == SatelliteLoaderInputAction, StateType == SatelliteLoaderState {
    static let satelliteLoaderReducer = Reducer.reduce { action, state in
        switch action {
        case .loadSatelliteCategory(_):
            break
        }
    }
}

extension Reducer where ActionType == SatelliteLoaderOutputAction, StateType == SatelliteLoaderState {
    static let satelliteLoaderReducer = Reducer.reduce { action, state in
        switch action {
        case let .loadedSatelliteInfo(category, info):
            state.info[category] = info
            logger.notice("Loaded \(info.count) TLE entries")
        case let .failedLoadingTLEFile(category, error):
            // TODO #1: handle TLE loading error
            print("Failed loading TLE for category \(String(describing: category)): \(error))")
            break
        }
    }
}
