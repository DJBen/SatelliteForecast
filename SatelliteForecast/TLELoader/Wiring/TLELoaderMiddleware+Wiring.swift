//
//  TLELoaderMiddleware+Wiring.swift
//  SatelliteForecast
//
//  Created by Ben Lu on 3/7/22.
//

import CombineRex

extension MiddlewareReader where MiddlewareType == EffectMiddleware<TLELoaderAction, TLELoaderOutput, TLELoaderState, TLELoaderDependencies>, Dependencies == TLELoaderDependencies {
    func lift() -> MiddlewareReader<TLELoaderDependencies, LiftMiddleware<AppAction, AppAction, AppState, EffectMiddleware<TLELoaderAction, TLELoaderOutput, TLELoaderState, TLELoaderDependencies>>> {
        return lift(
            inputAction: \AppAction.tleLoader,
            outputAction: AppAction.tleLoaderOutput,
            state: TLELoaderState.project(appState:)
        )
    }
}

extension EffectMiddleware where InputActionType == TLELoaderOutput, OutputActionType == SatelliteOverviewViewAction, StateType == TLELoaderState, Dependencies == Void {
    func lift() -> AnyMiddleware<AppAction, AppAction, AppState> {
        return lift(
            inputAction: \.tleLoaderOutput,
            outputAction: AppAction.satelliteOverview,
            state: TLELoaderState.project(appState:)
        )
        .eraseToAnyMiddleware()
    }
}

extension EffectMiddleware where InputActionType == TLELoaderOutput, OutputActionType == SatelliteListViewAction, StateType == TLELoaderState, Dependencies == Void {
    func lift() -> AnyMiddleware<AppAction, AppAction, AppState> {
        return lift(
            inputAction: \.tleLoaderOutput,
            outputAction: AppAction.satelliteListView,
            state: TLELoaderState.project(appState:)
        )
        .eraseToAnyMiddleware()
    }
}

extension EffectMiddleware where InputActionType == TLELoaderOutput, OutputActionType == AllPassesViewAction, StateType == TLELoaderState, Dependencies == Void {
    func lift() -> AnyMiddleware<AppAction, AppAction, AppState> {
        return lift(
            inputAction: \.tleLoaderOutput,
            outputAction: AppAction.allPassesView,
            state: TLELoaderState.project(appState:)
        )
        .eraseToAnyMiddleware()
    }
}
