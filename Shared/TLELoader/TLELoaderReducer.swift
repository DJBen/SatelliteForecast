//
//  TLELoaderReducer.swift
//  SatelliteForcast
//
//  Created by Ben Lu on 6/4/21.
//

import Foundation
import os
import SwiftRex

fileprivate let logger = Logger(subsystem: "io.djben.tleLoader", category: "reducer")

extension Reducer where ActionType == TLELoaderInputAction, StateType == TLELoaderState {
    static let tleLoaderReducer = Reducer.reduce { action, state in
        switch action {
        case .loadTLECategory(_):
            break
        }
    }
}

extension Reducer where ActionType == TLELoaderOutputAction, StateType == TLELoaderState {
    static let tleLoaderReducer = Reducer.reduce { action, state in
        switch action {
        case let .loadedTLEFile(category, tles):
            state.tles[category] = tles
            logger.notice("Loaded \(tles.count) TLE entries")
        case let .failedLoadingTLEFile(category, error):
            // TODO #1: handle TLE loading error
            print("Failed loading TLE for category \(String(describing: category)): \(error))")
            break
        }
    }
}
