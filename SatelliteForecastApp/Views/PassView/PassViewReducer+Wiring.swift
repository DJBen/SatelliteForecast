//
//  PassViewReducer+Wiring.swift
//  SatelliteForecastApp
//
//  Created by Ben Lu on 4/21/22.
//

import CombineRex
import SatelliteForecastImpl

extension Reducer where ActionType == PassViewAction, StateType == PassViewState {

    func lift() -> Reducer<AppAction, AppState> {
        lift(
            actionGetter: \.passView,
            stateGetter: PassViewState.project(appState:),
            stateSetter: PassViewState.apply(appState:state:)
        )
    }
}
