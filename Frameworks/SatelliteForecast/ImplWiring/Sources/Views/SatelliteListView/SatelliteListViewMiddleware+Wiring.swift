//
//  SatelliteListViewMiddleware+Wiring.swift
//  SatelliteForecastImplWiring
//
//  Created by Ben Lu on 11/23/22.
//

import Combine
import CombineRex
import SatelliteForecast
import SatelliteForecastImpl

extension EffectMiddleware where InputActionType == SatelliteListViewAction, OutputActionType == SatelliteListViewOutput, StateType == SatelliteListViewState, Dependencies == Void {

    public func lift() -> AnyMiddleware<AppAction, AppAction, AppState> {
        lift(
            inputAction: \.satelliteListView,
            outputAction: AppAction.satelliteListOutput,
            state: SatelliteListViewState.project(appState:)
        )
        .eraseToAnyMiddleware()
    }
}
