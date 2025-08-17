//
//  PassViewMiddleware+Wiring.swift
//  SatelliteForecastImplWiring
//
//  Created by Ben Lu on 5/13/22.
//

import Combine
@preconcurrency import CombineRex
import SatelliteForecast
import SatelliteForecastImpl

extension EffectMiddleware where InputActionType == PassViewAction, OutputActionType == PassViewAction, StateType == PassViewState, Dependencies == Void {
    public func lift() -> AnyMiddleware<AppAction, AppAction, AppState> {
        lift(
            inputAction: \.passView,
            outputAction: AppAction.passView,
            state: PassViewState.project(appState:)
        )
        .eraseToAnyMiddleware()
    }
}

extension EffectMiddleware where InputActionType == PassViewAction, OutputActionType == NotificationAction, StateType == PassViewState, Dependencies == Void {
    public func lift() -> AnyMiddleware<AppAction, AppAction, AppState> {
        lift(
            inputAction: \.passView,
            outputAction: AppAction.notification,
            state: PassViewState.project(appState:)
        )
        .eraseToAnyMiddleware()
    }
}
