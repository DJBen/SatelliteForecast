//
//  BackgroundSkyViewMiddleware+Wiring.swift
//  SatelliteForecast
//
//  Created by Ben Lu on 3/4/22.
//

import CombineRex

extension EffectMiddleware where InputActionType == BackgroundSkyViewAction, OutputActionType == BackgroundSkyViewOutput, StateType == BackgroundSkyResources, Dependencies == Void {

    func lift() -> AnyMiddleware<AppAction, AppAction, AppState> {
        lift(
            inputAction: \.backgroundSky,
            outputAction: AppAction.backgroundSkyOutput,
            state: { appState in appState.backgroundSkyResources }
        )
        .eraseToAnyMiddleware()
    }
}
