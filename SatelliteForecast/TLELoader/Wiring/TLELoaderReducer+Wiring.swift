//
//  TLELoaderReducer+Wiring.swift
//  SatelliteForecast
//
//  Created by Ben Lu on 3/7/22.
//

import SwiftRex

extension Reducer where ActionType == TLELoaderAction, StateType == TLELoaderState {
    func lift() -> Reducer<AppAction, AppState> {
        lift(
            actionGetter: \.tleLoader,
            stateGetter: TLELoaderState.project(appState:),
            stateSetter: TLELoaderState.apply(appState:state:)
        )
    }
}

extension Reducer where ActionType == TLELoaderOutput, StateType == TLELoaderState {
    func lift() -> Reducer<AppAction, AppState> {
        lift(
            actionGetter: \.tleLoaderOutput,
            stateGetter: TLELoaderState.project(appState:),
            stateSetter: TLELoaderState.apply(appState:state:)
        )
    }
}
