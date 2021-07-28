//
//  TimerReducer.swift
//  SatelliteForecast
//
//  Created by Ben Lu on 6/7/21.
//

import Foundation
import os
import SwiftRex
import SatelliteKit

fileprivate let logger = Logger(subsystem: "io.djben.timer", category: "reducer")

extension Reducer where ActionType == TimerAction, StateType == AppState {
    static let timerReducer = Reducer.reduce { action, state in
        switch action {
        case .start:
            break
        case let .tick(currentDate):
            state.satelliteLoaderState.currentDate = currentDate
        }
    }
}
