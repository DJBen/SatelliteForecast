//
//  ElementsPropagatorMiddleware+Wiring.swift
//  SatelliteForecastApp
//
//  Created by Ben Lu on 4/4/22.
//

import CombineRex
import CombineRextensions
import SatelliteForecast
import SatelliteForecastImpl

extension EffectMiddleware where InputActionType == ElementsPropagatorAction, OutputActionType == ElementsPropagatorOutput, StateType == ElementsPropagatorResources, Dependencies == Void {
    func lift() -> AnyMiddleware<AppAction, AppAction, AppState> {
        lift(
            inputAction: \.elementsPropagator,
            outputAction: AppAction.elementsPropagatorOutput,
            state: ElementsPropagatorResources.project(appState:)
        )
        .eraseToAnyMiddleware()
    }
}

extension EffectMiddleware where InputActionType == ElementsPropagatorAction, OutputActionType == ElementsPropagatorAction, StateType == ElementsPropagatorResources, Dependencies == Void {
    func lift() -> AnyMiddleware<AppAction, AppAction, AppState> {
        lift(
            inputAction: \.elementsPropagator,
            outputAction: AppAction.elementsPropagator,
            state: ElementsPropagatorResources.project(appState:)
        )
        .eraseToAnyMiddleware()
    }
}
