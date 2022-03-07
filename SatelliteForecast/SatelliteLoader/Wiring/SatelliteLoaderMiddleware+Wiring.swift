//
//  SatelliteLoaderMiddleware+Wiring.swift
//  SatelliteForecast
//
//  Created by Ben Lu on 3/7/22.
//

import CombineRex

extension MiddlewareReader where MiddlewareType == EffectMiddleware<SatelliteLoaderAction, SatelliteLoaderOutput, SatelliteLoaderState, SatelliteLoaderDependencies>, Dependencies == SatelliteLoaderDependencies {
    func lift() -> MiddlewareReader<SatelliteLoaderDependencies, LiftMiddleware<AppAction, AppAction, AppState, EffectMiddleware<SatelliteLoaderAction, SatelliteLoaderOutput, SatelliteLoaderState, SatelliteLoaderDependencies>>> {
        return lift(
            inputAction: \AppAction.satelliteLoader,
            outputAction: AppAction.satelliteLoaderOutput,
            state: SatelliteLoaderState.project(appState:)
        )
    }
}

extension EffectMiddleware where InputActionType == SatelliteLoaderOutput, OutputActionType == SatelliteOverviewViewAction, StateType == SatelliteLoaderState, Dependencies == Void {
    func lift() -> AnyMiddleware<AppAction, AppAction, AppState> {
        return lift(
            inputAction: \.satelliteLoaderOutput,
            outputAction: AppAction.satelliteOverview,
            state: SatelliteLoaderState.project(appState:)
        )
        .eraseToAnyMiddleware()
    }
}

extension EffectMiddleware where InputActionType == SatelliteLoaderOutput, OutputActionType == SatelliteListViewAction, StateType == SatelliteLoaderState, Dependencies == Void {
    func lift() -> AnyMiddleware<AppAction, AppAction, AppState> {
        return lift(
            inputAction: \.satelliteLoaderOutput,
            outputAction: AppAction.satelliteListView,
            state: SatelliteLoaderState.project(appState:)
        )
        .eraseToAnyMiddleware()
    }
}

extension EffectMiddleware where InputActionType == SatelliteLoaderOutput, OutputActionType == AllPassesViewAction, StateType == SatelliteLoaderState, Dependencies == Void {
    func lift() -> AnyMiddleware<AppAction, AppAction, AppState> {
        return lift(
            inputAction: \.satelliteLoaderOutput,
            outputAction: AppAction.allPassesView,
            state: SatelliteLoaderState.project(appState:)
        )
        .eraseToAnyMiddleware()
    }
}
