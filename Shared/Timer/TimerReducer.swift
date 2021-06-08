//
//  TimerReducer.swift
//  SatelliteForcast (iOS)
//
//  Created by Ben Lu on 6/7/21.
//

import Foundation
import SwiftRex

extension Reducer where ActionType == TimerAction, StateType == AppState {
    static let timerReducer = Reducer.reduce { action, state in
        switch action {
        case .start:
            break
        case let .tick(currentDate):
            state.tleLoaderState.referenceDate = currentDate
            state.skyChartState.skyReferenceDate = currentDate

            // Advance date range every 5 mins
            if currentDate.timeIntervalSince(state.dateRange.lowerBound.addingTimeInterval(60 * 60 * 2)) > 10 * 60 {
                state.dateRange = currentDate.advanced(by: -60 * 60 * 2)..<currentDate.advanced(by: 60 * 60 * 22)
            }
        }
    }
}
