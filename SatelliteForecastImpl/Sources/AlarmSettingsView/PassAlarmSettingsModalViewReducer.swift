//
//  PassAlarmSettingsModalViewReducer.swift
//  SatelliteForecastImpl
//
//  Created by Ben Lu on 4/22/22.
//

import SwiftRex

extension Reducer where ActionType == PassAlarmSettingsModalViewAction, StateType == PassAlarmSettingsModalViewState {
    public static let passAlarmSettingsModalReducer = Reducer.reduce { action, state in
        switch action {
        case .dismissModal:
            state.showAlarmConfigurationModal = false
        case .scheduleAlarm(_):
            state.showAlarmConfigurationModal = false
        }
    }
}
