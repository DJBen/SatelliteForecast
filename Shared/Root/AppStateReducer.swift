//
//  AppStateReducer.swift
//  SatelliteForcast
//
//  Created by Ben Lu on 6/20/21.
//

import Foundation
import os
import SwiftRex

fileprivate let logger = Logger(subsystem: "io.djben.appState", category: "reducer")

extension Reducer where ActionType == AppAction, StateType == Store.StateType {
    static let appStateReducer = Reducer.reduce { action, state in
        switch action {
        case let .freezeObserverLocation(observer):
            state.observerForPasses = observer
            logger.debug("Freezes observer coordinate to \(String(describing: observer))")
        default:
            break
        }
    }
}
