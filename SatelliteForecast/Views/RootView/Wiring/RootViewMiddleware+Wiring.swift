//
//  RootViewMiddleware+Wiring.swift
//  SatelliteForecast
//
//  Created by Ben Lu on 3/7/22.
//

import CombineRex

extension EffectMiddleware where InputActionType == RootViewAction, OutputActionType == TLELoaderAction, StateType == RootViewState, Dependencies == Void {
    func lift() -> AnyMiddleware<AppAction, AppAction, AppState> {
        lift(
            inputAction: \.rootView,
            outputAction: AppAction.tleLoader,
            state: RootViewState.project(appState:)
        )
        .eraseToAnyMiddleware()
    }
}
