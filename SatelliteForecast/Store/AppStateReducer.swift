//
//  AppStateReducer.swift
//  SatelliteForecast
//
//  Created by Ben Lu on 6/20/21.
//

import Foundation
import os
import SwiftRex

fileprivate let logger = Logger(subsystem: "io.djben.appState", category: "reducer")

extension Reducer where ActionType == AppAction, StateType == AppState {
    static let appStateReducer = Reducer.reduce { action, state in
        switch action {
        default:
            break
        }
    }
}
