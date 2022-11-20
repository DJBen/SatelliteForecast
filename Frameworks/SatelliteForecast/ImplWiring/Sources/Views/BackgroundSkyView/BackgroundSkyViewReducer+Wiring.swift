//
//  BackgroundSkyViewReducer+Wiring.swift
//  SatelliteForecast
//
//  Created by Ben Lu on 3/4/22.
//

import SwiftRex
import SatelliteForecast
import SatelliteForecastImpl

extension Reducer where ActionType == BackgroundSkyViewOutput, StateType == BackgroundSkyResources {
    public func lift() -> Reducer<AppAction, AppState> {
        lift(
            actionGetter: \.backgroundSkyOutput,
            stateGetter: BackgroundSkyResources.project(appState:),
            stateSetter: BackgroundSkyResources.apply(appState:state:)
        )
    }
}
