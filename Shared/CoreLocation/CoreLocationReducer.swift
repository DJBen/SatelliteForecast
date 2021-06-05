//
//  CoreLocationReducer.swift
//  SatelliteForcast
//
//  Created by Ben Lu on 6/4/21.
//

import Foundation
import SwiftRex

extension Reducer where ActionType == CoreLocationOutputAction, StateType == CoreLocationState {
    static let coreLocationReducer = Reducer.reduce { action, state in
        switch action {
        case let .authorizationDidChange(authorizationStatus):
            state.authorizationStatus = authorizationStatus
        case let .locationChanged(location):
            state.location = location
        }
    }
}
