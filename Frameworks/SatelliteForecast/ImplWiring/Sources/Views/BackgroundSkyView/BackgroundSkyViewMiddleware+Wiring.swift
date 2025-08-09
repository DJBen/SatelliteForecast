//
//  BackgroundSkyViewMiddleware+Wiring.swift
//  SatelliteForecast
//
//  Created by Ben Lu on 3/4/22.
//

@preconcurrency import CombineRex
import SatelliteForecast
import SatelliteForecastImpl
import StarryNight

extension MiddlewareReader where MiddlewareType == BackgroundSkyEffectMiddleware, Dependencies == any StarManaging {
    public func lift(dependencies: any StarManaging) -> AnyMiddleware<AppAction, AppAction, AppState> {
        lift(
            inputAction: \.backgroundSky,
            outputAction: AppAction.backgroundSkyOutput,
            state: BackgroundSkyResources.project(appState:)
        )
        .inject(
            dependencies
        )
        .eraseToAnyMiddleware()
    }
}
