//
//  NavigationReducer.swift
//  SatelliteForecastApp
//
//  Created by Ben Lu on 4/4/22.
//

import SwiftRex
import SatelliteForecast
import SatelliteForecastImpl

extension Reducer where ActionType == LocationAction, StateType == NavigationState {
    static let navigationReducerFromLocationAction = Reducer.reduce { action, state in
        switch action {
        case .selectLocation(let location):
            if state.observerNavigation.enabled {
                state.observerNavigation.enabled = false
            }
        default:
            break
        }
    }

    func lift() -> Reducer<AppAction, AppState> {
        lift(
            action: \.location,
            state: \.navigationState
        )
    }
}
