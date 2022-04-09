//
//  SatelliteOverviewReducer+Wiring.swift
//  SatelliteForecast
//
//  Created by Ben Lu on 3/6/22.
//

import SwiftRex
import SatelliteForecast
import SatelliteForecastImpl

extension Reducer where ActionType == SatelliteOverviewViewAction, StateType == SatelliteOverviewViewState {
    func lift() -> Reducer<AppAction, AppState> {
        lift(
            actionGetter: \.satelliteOverview,
            stateGetter: SatelliteOverviewViewState.project(appState:),
            stateSetter: SatelliteOverviewViewState.apply(appState:state:)
        )
    }
}
