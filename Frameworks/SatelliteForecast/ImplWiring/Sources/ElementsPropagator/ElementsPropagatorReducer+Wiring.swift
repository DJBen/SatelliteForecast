//
//  ElementsPropagatorReducer+Wiring.swift
//  SatelliteForecast
//
//  Created by Ben Lu on 3/7/22.
//

import SwiftRex
import SatelliteForecast
import SatelliteForecastImpl

extension Reducer where ActionType == ElementsPropagatorAction, StateType == ElementsPropagatorResources {
    public func lift() -> Reducer<AppAction, AppState> {
        lift(
            actionGetter: \.elementsPropagator,
            stateGetter: ElementsPropagatorResources.project(appState:),
            stateSetter: ElementsPropagatorResources.apply(appState:state:)
        )
    }
}

extension Reducer where ActionType == ElementsPropagatorOutput, StateType == ElementsPropagatorResources {
    public func lift() -> Reducer<AppAction, AppState> {
        lift(
            actionGetter: \.elementsPropagatorOutput,
            stateGetter: ElementsPropagatorResources.project(appState:),
            stateSetter: ElementsPropagatorResources.apply(appState:state:)
        )
    }
}
