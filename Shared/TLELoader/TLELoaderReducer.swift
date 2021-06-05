//
//  TLELoaderReducer.swift
//  SatelliteForcast
//
//  Created by Ben Lu on 6/4/21.
//

import Foundation
import SwiftRex

extension Reducer where ActionType == TLELoaderInputAction, StateType == TLELoaderState {
    static let tleLoaderReducer = Reducer.reduce { action, state in
        switch action {
        case let .willLoadTLECategory(category):
            switch state.tles[category] {
            case nil, .neverLoaded:
                state.tles[category] = .loading
            case .loading, .loaded(_):
                break
            }

        case .loadTLECategories:
            break
        }
    }
}


extension Reducer where ActionType == TLELoaderOutputAction, StateType == TLELoaderState {
    static let tleLoaderReducer = Reducer.reduce { action, state in
        switch action {
        case let .loadedTLEFile(category, tles):
            state.tles[category] = .loaded(tles)
        case let .failedLoadingTLEFile(category, error):
            // TODO #1: handle TLE loading error
            print("Failed loading TLE for category \(String(describing: category)): \(error))")
            break
        }
    }
}
