//
//  AllPassesViewReducer+Wiring.swift
//  SatelliteForecastApp
//
//  Created by Ben Lu on 4/3/22.
//

import SwiftRex

extension Reducer where ActionType == AllPassesViewAction, StateType == AllPassesViewState {
    func lift() -> Reducer<AppAction, AppState> {
        lift(
            actionGetter: \.allPassesView,
            stateGetter: AllPassesViewState.project(appState:),
            stateSetter: AllPassesViewState.apply(appState:state:)
        )
    }
}
