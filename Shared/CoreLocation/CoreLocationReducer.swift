//
//  CoreLocationReducer.swift
//  SatelliteForecast
//
//  Created by Ben Lu on 6/4/21.
//

import Foundation
import SwiftRex

extension Reducer where ActionType == CoreLocationAction, StateType == CoreLocationState {
    static let coreLocationReducer = Reducer.reduce { action, state in
        switch action {
        case .requestAuthorization:
            break
        case let .authorizationDidChange(authorizationStatus):
            state.authorizationStatus = authorizationStatus
        case let .locationChanged(location):
            state.location = location
        }
    }
}
