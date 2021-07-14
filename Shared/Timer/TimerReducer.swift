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

            // Advance date range every 10 mins
            if currentDate - (state.julianDateRange.lowerBound + TimeConstants.hrs2day * 2) > 10 * TimeConstants.min2day {
                state.julianDateRange = currentDate.advanced(by: -60 * 60 * 2)..<currentDate.advanced(by: 60 * 60 * 22)
            }
        }
    }
}
