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
        case .loadSatelliteCategory(_, _):
            break
        case let .loadedSatelliteInfo(category, info):
            state.info[category] = .success(info)
            logger.notice("Loaded \(info.count) TLE entries")
        case let .failedLoadingTLEFile(category, error):
            state.info[category] = .failure(error)
            logger.error("Failed loading TLE for category \(String(describing: category)): \(String(describing: error))")
            break
        }
    }
}
