//
//  PassAlarmSettingsModalViewReducer.swift
//  SatelliteForecastImpl
//
//  Created by Ben Lu on 4/22/22.
//

@preconcurrency import SwiftRex
import SatelliteForecast

extension Reducer where ActionType == PassAlarmSettingsModalViewAction, StateType == PassAlarmSettingsModalViewState {
    public static let passAlarmSettingsModalReducer = Reducer.reduce { action, state in
        switch action {
        case .dismissModal:
            state.showAlarmConfigurationModal = false
        case .scheduleAlarm(_, _):
            state.showAlarmConfigurationModal = false
        case .unscheduleAlarm(_):
            state.showAlarmConfigurationModal = false
        }
    }
}
