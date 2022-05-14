//
//  PassViewMiddleware+Wiring.swift
//  SatelliteForecastApp
//
//  Created by Ben Lu on 5/13/22.
//

import Combine
import CombineRex
import SatelliteForecastImpl

extension EffectMiddleware where InputActionType == PassViewAction, OutputActionType == PassViewAction, StateType == PassViewState, Dependencies == Void {
    func lift() -> SimpleEffectMiddleware<AppAction, AppState> {
        lift(
            inputAction: \.passView,
            outputAction: AppAction.passView,
            state: PassViewState.project(appState:)
        )
    }
}
