//
//  AllPassesViewReducer+Wiring.swift
//  SatelliteForecastImplWiring
//
//  Created by Ben Lu on 4/3/22.
//

@preconcurrency import SwiftRex
import SatelliteForecastImpl

extension Reducer where ActionType == AllPassesViewAction, StateType == AllPassesViewState {
    public func lift() -> Reducer<AppAction, AppState> {
        lift(
            actionGetter: \.allPassesView,
            stateGetter: AllPassesViewState.project(appState:),
            stateSetter: AllPassesViewState.apply(appState:state:)
        )
    }
}
