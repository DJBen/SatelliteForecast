//
//  AllPassesViewReducer.swift
//  SatelliteForecastImpl
//
//  Created by Ben Lu on 6/17/21.
//

import Foundation
@preconcurrency import SwiftRex
@preconcurrency import SatelliteKit

extension Reducer where ActionType == AllPassesViewAction, StateType == AllPassesViewState {
    public static let allPassesViewReducer = Reducer.reduce { action, state in
        switch action {
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

