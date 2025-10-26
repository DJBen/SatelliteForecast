//
//  PassViewReducer.swift
//  SatelliteForecast
//
//  Created by Ben Lu on 4/21/22.
//

import Foundation
import SatelliteForecast
@preconcurrency import SwiftRex

extension Reducer where ActionType == PassViewAction, StateType == PassViewState {
    public static let passViewReducer = Reducer.reduce { action, state in
        switch action {
        case .showAlarmConfiguration(let isShowing):
            state.showAlarmConfigurationModal = isShowing
        case .showDetailPassView(let showsDetailPassView):
            state.showsDetailPassView = showsDetailPassView
        case .unscheduleAlarm(_):
            break
        }
    }
}
