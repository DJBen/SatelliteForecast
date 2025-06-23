//
//  PassViewReducer+Wiring.swift
//  SatelliteForecastImplWiring
//
//  Created by Ben Lu on 4/21/22.
//

@preconcurrency import CombineRex
import SatelliteForecastImpl

extension Reducer where ActionType == PassViewAction, StateType == PassViewState {
    public func lift() -> Reducer<AppAction, AppState> {
        lift(
            actionGetter: \.passView,
            stateGetter: PassViewState.project(appState:),
            stateSetter: PassViewState.apply(appState:state:)
        )
    }
}
