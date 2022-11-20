//
//  PassAlarmSettingsModalViewReducer+Wiring.swift
//  SatelliteForecastImplWiring
//
//  Created by Ben Lu on 4/22/22.
//

import SwiftRex
import SatelliteForecastImpl

extension Reducer where ActionType == PassAlarmSettingsModalViewAction, StateType == PassAlarmSettingsModalViewState {
    public func lift() -> Reducer<AppAction, AppState> {
        lift(
            actionGetter: \.passAlarmSettings,
            stateGetter: PassAlarmSettingsModalViewState.project(appState:),
            stateSetter: PassAlarmSettingsModalViewState.apply(appState:state:)
        )
    }
}
