//
//  RootViewMiddleware+Wiring.swift
//  SatelliteForecast
//
//  Created by Ben Lu on 3/7/22.
//

import CombineRex
import SatelliteForecastImpl

extension EffectMiddleware where InputActionType == RootViewAction, OutputActionType == ElementsLoaderAction, StateType == RootViewState, Dependencies == Void {
    public func lift() -> AnyMiddleware<AppAction, AppAction, AppState> {
        lift(
            inputAction: \.rootView,
            outputAction: AppAction.elementsLoader,
            state: RootViewState.project(appState:)
        )
        .eraseToAnyMiddleware()
    }
}
