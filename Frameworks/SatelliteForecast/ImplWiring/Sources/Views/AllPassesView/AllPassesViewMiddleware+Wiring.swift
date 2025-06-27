//
//  AllPassesViewMiddleware+ElementsPropagator.swift
//  SatelliteForecastImplWiring
//
//  Created by Ben Lu on 4/4/22.
//

@preconcurrency import CombineRex
import SatelliteForecast
import SatelliteForecastImpl

extension EffectMiddleware where InputActionType == AllPassesViewAction, OutputActionType == ElementsPropagatorAction, StateType == Void, Dependencies == Void {
    public func lift() -> AnyMiddleware<AppAction, AppAction, AppState> {
        lift(
            inputAction: \.allPassesView,
            outputAction: AppAction.elementsPropagator,
            state: { _ in }
        )
        .eraseToAnyMiddleware()
    }
}

extension EffectMiddleware where InputActionType == AllPassesViewAction, OutputActionType == NotificationAction, StateType == Void, Dependencies == Void {
    public func lift() -> AnyMiddleware<AppAction, AppAction, AppState> {
        lift(
            inputAction: \.allPassesView,
            outputAction: AppAction.notification,
            state: { _ in }
        )
        .eraseToAnyMiddleware()
    }
}
