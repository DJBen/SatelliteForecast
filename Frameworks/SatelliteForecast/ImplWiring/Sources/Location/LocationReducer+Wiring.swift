//
//  LocationReducer+Wiring.swift
//  SatelliteForecastImplWiring
//
//  Created by Ben Lu on 4/4/22.
//

@preconcurrency import SwiftRex
import SatelliteForecast
import SatelliteForecastImpl

extension Reducer where ActionType == LocationAction, StateType == LocationState {
    public func lift() -> Reducer<AppAction, AppState> {
        lift(
            actionGetter: \.location,
            stateGetter: LocationState.project(appState:),
            stateSetter: LocationState.apply(appState:state:)
        )
    }
}

extension Reducer where ActionType == LocationOutput, StateType == LocationState {
    public func lift() -> Reducer<AppAction, AppState> {
        lift(
            actionGetter: \.locationOutput,
            stateGetter: LocationState.project(appState:),
            stateSetter: LocationState.apply(appState:state:)
        )
    }
}
