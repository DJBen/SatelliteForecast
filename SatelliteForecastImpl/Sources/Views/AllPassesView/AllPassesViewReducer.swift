//
//  AllPassesViewReducer.swift
//  SatelliteForecast
//
//  Created by Ben Lu on 6/17/21.
//

import Foundation
import SwiftRex
import SatelliteKit

extension Reducer where ActionType == AllPassesViewAction, StateType == AllPassesViewState {
    public static let allPassesViewReducer = Reducer.reduce { action, state in
        switch action {
        case let .selectPass(index):
            state.selectedPassIndex = index
        case .calculatePasses:
            break
        case .recalculatePasses:
            break
        case .scheduleNotification(_, _):
            break
        case .unscheduleNotification(_):
            break
        }
    }
}

