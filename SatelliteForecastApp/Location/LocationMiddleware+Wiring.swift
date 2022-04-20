//
//  LocationMiddleware+Wiring.swift
//  SatelliteForecastApp
//
//  Created by Ben Lu on 4/4/22.
//

import CombineRex
import SatelliteForecast
import SatelliteForecastImpl
import Darwin

extension LocationMiddleware {
    func lift() -> AnyMiddleware<AppAction, AppAction, AppState> {
        return lift(
            inputAction: \AppAction.location,
            outputAction: AppAction.locationOutput,
            state: \AppState.locationResources
        )
        .eraseToAnyMiddleware()
    }
}

extension EffectMiddleware where InputActionType == LocationOutput, OutputActionType == Never, StateType == Void, Dependencies == Void {
    func lift() -> AnyMiddleware<AppAction, AppAction, AppState> {
        func appActionToNever(_ never: Never) -> AppAction {
        }
        return lift(
            inputAction: \.locationOutput,
            outputAction: appActionToNever,
            state: { _ in }
        )
        .eraseToAnyMiddleware()
    }
}

extension EffectMiddleware where InputActionType == LocationOutput, OutputActionType == LocationAction, StateType == LocationState, Dependencies == Void {
    func lift() -> AnyMiddleware<AppAction, AppAction, AppState> {
        return lift(
            inputAction: \.locationOutput,
            outputAction: AppAction.location,
            state: LocationState.project(appState:)
        )
        .eraseToAnyMiddleware()
    }
}
