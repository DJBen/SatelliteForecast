//
//  SatelliteLoaderReducer+Wiring.swift
//  SatelliteForecast
//
//  Created by Ben Lu on 3/7/22.
//

import SwiftRex

extension Reducer where ActionType == SatelliteLoaderAction, StateType == SatelliteLoaderState {
    func lift() -> Reducer<AppAction, AppState> {
        lift(
            actionGetter: \.satelliteLoader,
            stateGetter: SatelliteLoaderState.project(appState:),
            stateSetter: SatelliteLoaderState.apply(appState:state:)
        )
    }
}

extension Reducer where ActionType == SatelliteLoaderOutput, StateType == SatelliteLoaderState {
    func lift() -> Reducer<AppAction, AppState> {
        lift(
            actionGetter: \.satelliteLoaderOutput,
            stateGetter: SatelliteLoaderState.project(appState:),
            stateSetter: SatelliteLoaderState.apply(appState:state:)
        )
    }
}
