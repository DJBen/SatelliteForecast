//
//  ElementsLoaderMiddleware+Wiring.swift
//  SatelliteForecast
//
//  Created by Ben Lu on 3/7/22.
//

import CombineRex
import SatelliteForecastImpl

extension MiddlewareReader where MiddlewareType == ElementsLoaderEffectMiddleware, Dependencies == ElementsLoaderDependencies {
    func lift(dependencies: ElementsLoaderDependencies) -> AnyMiddleware<AppAction, AppAction, AppState> {
        return lift(
            inputAction: \AppAction.elementsLoader,
            outputAction: AppAction.elementsLoaderOutput,
            state: ElementsLoaderState.project(appState:)
        )
        .inject(
            dependencies
        )
        .eraseToAnyMiddleware()
    }
}

extension EffectMiddleware where InputActionType == ElementsLoaderOutput, OutputActionType == SatelliteOverviewViewAction, StateType == ElementsLoaderState, Dependencies == Void {
    func lift() -> AnyMiddleware<AppAction, AppAction, AppState> {
        return lift(
            inputAction: \.elementsLoaderOutput,
            outputAction: AppAction.satelliteOverview,
            state: ElementsLoaderState.project(appState:)
        )
        .eraseToAnyMiddleware()
    }
}

extension EffectMiddleware where InputActionType == ElementsLoaderOutput, OutputActionType == SatelliteListViewAction, StateType == ElementsLoaderState, Dependencies == Void {
    func lift() -> AnyMiddleware<AppAction, AppAction, AppState> {
        return lift(
            inputAction: \.elementsLoaderOutput,
            outputAction: AppAction.satelliteListView,
            state: ElementsLoaderState.project(appState:)
        )
        .eraseToAnyMiddleware()
    }
}

extension EffectMiddleware where InputActionType == ElementsLoaderOutput, OutputActionType == AllPassesViewAction, StateType == ElementsLoaderState, Dependencies == Void {
    func lift() -> AnyMiddleware<AppAction, AppAction, AppState> {
        return lift(
            inputAction: \.elementsLoaderOutput,
            outputAction: AppAction.allPassesView,
            state: ElementsLoaderState.project(appState:)
        )
        .eraseToAnyMiddleware()
    }
}
