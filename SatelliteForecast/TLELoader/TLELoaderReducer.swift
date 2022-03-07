//
//  TLELoaderReducer.swift
//  SatelliteForecast
//
//  Created by Ben Lu on 6/4/21.
//

import Foundation
import os
import SwiftRex

fileprivate let logger = Logger(subsystem: "io.djben.tleLoader", category: "reducer")

extension Reducer where ActionType == TLELoaderAction, StateType == TLELoaderState {
    static let tleLoaderReducer = Reducer.reduce { action, state in
        switch action {
        case .loadSatelliteTLEs(let category, _, _, _):
            state.resources.info[category] = .loading
        }
    }
}

extension Reducer where ActionType == TLELoaderOutput, StateType == TLELoaderState {
    static let tleLoaderOutputReducer = Reducer.reduce { action, state in
        switch action {
        case let .loadedSatelliteTLEs(category, info, _, _, _):
            state.resources.info[category] = .loaded(info)
            logger.notice("Loaded \(info.count) TLE entries")
        case let .failedLoadingTLEFile(category, error):
            state.resources.info[category] = .failed(error)
            logger.error("Failed loading TLE for category \(String(describing: category)): \(String(describing: error))")
            break
        }
    }
}
