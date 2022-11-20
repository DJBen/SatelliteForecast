//
//  RootViewReducer+Wiring.swift
//  SatelliteForecast
//
//  Created by Ben Lu on 3/6/22.
//

import SwiftRex

extension Reducer where ActionType == RootViewAction, StateType == RootViewState {
    public func lift() -> Reducer<AppAction, AppState> {
        lift(
            actionGetter: \.rootView,
            stateGetter: RootViewState.project(appState:),
            stateSetter: RootViewState.apply(appState:state:)
        )
    }
}
