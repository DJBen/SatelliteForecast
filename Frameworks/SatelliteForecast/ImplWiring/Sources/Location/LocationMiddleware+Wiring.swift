//
//  LocationMiddleware+Wiring.swift
//  SatelliteForecastImplWiring
//
//  Created by Ben Lu on 4/4/22.
//

@preconcurrency import CombineRex
import SatelliteForecast
import SatelliteForecastImpl
import Darwin

extension LocationMiddleware {
    public func lift() -> AnyMiddleware<AppAction, AppAction, AppState> {
        return lift(
            inputAction: \AppAction.location,
            outputAction: AppAction.locationOutput,
            state: \AppState.locationResources
        )
        .eraseToAnyMiddleware()
    }
}

extension EffectMiddleware where InputActionType == LocationOutput, OutputActionType == Never, StateType == Void, Dependencies == Void {
    public func lift() -> AnyMiddleware<AppAction, AppAction, AppState> {
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
    public func lift() -> AnyMiddleware<AppAction, AppAction, AppState> {
        return lift(
            inputAction: \.locationOutput,
            outputAction: AppAction.location,
            state: LocationState.project(appState:)
        )
        .eraseToAnyMiddleware()
    }
}

extension EffectMiddleware where InputActionType == LocationAction, OutputActionType == RealtimeSkyViewAction, StateType == Void, Dependencies == Void {
    public func lift() -> AnyMiddleware<AppAction, AppAction, AppState> {
        return lift(
            inputAction: \.location,
            outputAction: AppAction.realtimeSky,
            state: { _ in }
        )
        .eraseToAnyMiddleware()
    }
}

extension EffectMiddleware where InputActionType == LocationAction, OutputActionType == ElementsPropagatorAction, StateType == Void, Dependencies == Void {
    public func lift() -> AnyMiddleware<AppAction, AppAction, AppState> {
        return lift(
            inputAction: \.location,
            outputAction: AppAction.elementsPropagator,
            state: { _ in }
        )
        .eraseToAnyMiddleware()
    }
}
