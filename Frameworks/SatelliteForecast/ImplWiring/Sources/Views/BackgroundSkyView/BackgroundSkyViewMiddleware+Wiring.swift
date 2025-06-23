//
//  BackgroundSkyViewMiddleware+Wiring.swift
//  SatelliteForecast
//
//  Created by Ben Lu on 3/4/22.
//

@preconcurrency import CombineRex
import SatelliteForecast
import SatelliteForecastImpl

extension EffectMiddleware where InputActionType == BackgroundSkyViewAction, OutputActionType == BackgroundSkyViewOutput, StateType == BackgroundSkyResources, Dependencies == Void {

    public func lift() -> AnyMiddleware<AppAction, AppAction, AppState> {
        lift(
            inputAction: \.backgroundSky,
            outputAction: AppAction.backgroundSkyOutput,
            state: BackgroundSkyResources.project(appState:)
        )
        .eraseToAnyMiddleware()
    }
}
