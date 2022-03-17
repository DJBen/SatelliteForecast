//
//  ElementsLoaderReducer+Wiring.swift
//  SatelliteForecast
//
//  Created by Ben Lu on 3/7/22.
//

import SwiftRex

extension Reducer where ActionType == ElementsLoaderAction, StateType == ElementsLoaderState {
    func lift() -> Reducer<AppAction, AppState> {
        lift(
            actionGetter: \.elementsLoader,
            stateGetter: ElementsLoaderState.project(appState:),
            stateSetter: ElementsLoaderState.apply(appState:state:)
        )
    }
}

extension Reducer where ActionType == ElementsLoaderOutput, StateType == ElementsLoaderState {
    func lift() -> Reducer<AppAction, AppState> {
        lift(
            actionGetter: \.elementsLoaderOutput,
            stateGetter: ElementsLoaderState.project(appState:),
            stateSetter: ElementsLoaderState.apply(appState:state:)
        )
    }
}
