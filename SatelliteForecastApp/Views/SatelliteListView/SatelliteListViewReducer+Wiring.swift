//
//  SatelliteListViewReducer+Wiring.swift
//  SatelliteForecastApp
//
//  Created by Ben Lu on 4/8/22.
//

import SatelliteForecastImpl
import SwiftRex

extension Reducer where ActionType == SatelliteListViewAction, StateType == SatelliteListViewState {
    func lift() -> Reducer<AppAction, AppState> {
        lift(
            actionGetter: \.satelliteListView,
            stateGetter: SatelliteListViewState.project(appState:),
            stateSetter: SatelliteListViewState.apply(appState:state:)
        )
    }
}
