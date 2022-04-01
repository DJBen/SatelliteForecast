//
//  SettingsOverviewReducer+Wiring.swift
//  SatelliteForecast
//
//  Created by Ben Lu on 3/30/22.
//

import SwiftRex

extension Reducer where ActionType == SettingsOverviewViewAction, StateType == SettingsOverviewViewState {
    func lift() -> Reducer<AppAction, AppState> {
        lift(
            actionGetter: \.settingsOverview,
            stateGetter: SettingsOverviewViewState.project(appState:),
            stateSetter: SettingsOverviewViewState.apply(appState:state:)
        )
    }
}
