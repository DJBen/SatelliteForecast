//
//  AllPassesViewReducer.swift
//  SatelliteForecast
//
//  Created by Ben Lu on 6/17/21.
//

import Foundation
import SwiftRex
import SatelliteKit

extension Reducer where ActionType == AllPassesViewAction, StateType == AppState {
    static let allPassesViewReducer = Reducer.reduce { action, state in
        switch action {
        case .calculatePasses:
            break
        case .recalculatePasses:
            break
        case let .selectPass(index):
            if let index = index {
                state.navigationState.selectPass(index: index)
            } else {
                state.navigationState.deselectPass()
            }
        case .scheduleNotification(_):
            break
        case .unscheduleNotification(_):
            break
        }
    }
}

