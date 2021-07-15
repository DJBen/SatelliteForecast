//
//  TimerReducer.swift
//  SatelliteForcast
//
//  Created by Ben Lu on 6/7/21.
//

import Foundation
import SwiftRex
import SatelliteKit

extension Reducer where ActionType == TimerAction, StateType == AppState {
    static let timerReducer = Reducer.reduce { action, state in
        switch action {
        case .start:
            break
        case let .tick(currentDate):
            state.satelliteLoaderState.referenceDate = currentDate
        }
    }
}
