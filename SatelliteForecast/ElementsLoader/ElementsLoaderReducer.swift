//
//  ElementsLoaderReducer.swift
//  SatelliteForecast
//
//  Created by Ben Lu on 6/4/21.
//

import Foundation
import os
import SwiftRex

fileprivate let logger = Logger(subsystem: "io.djben.elementsLoader", category: "reducer")

extension Reducer where ActionType == ElementsLoaderAction, StateType == ElementsLoaderState {
    public static let elementsLoaderReducer = Reducer.reduce { action, state in
        switch action {
        case .loadElements(let category, _, _, _):
            state.resources.info[category] = .loading
        }
    }
}

extension Reducer where ActionType == ElementsLoaderOutput, StateType == ElementsLoaderState {
    public static let elementsLoaderOutputReducer = Reducer.reduce { action, state in
        switch action {
        case let .loadedSatelliteElements(category, info, _, _, _):
            state.resources.info[category] = .loaded(info)
            logger.notice("Loaded \(info.count) Elements entries")
        case let .failedLoadingElements(category, error):
            state.resources.info[category] = .failed(error)
            logger.error("Failed loading Elements for category \(String(describing: category)): \(String(describing: error))")
            break
        }
    }
}
