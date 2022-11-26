//
//  SettingsOverviewReducer.swift
//  SatelliteForecastImpl
//
//  Created by Ben Lu on 3/30/22.
//

import Foundation
import SwiftRex

extension Reducer where ActionType == SettingsOverviewViewAction, StateType == SettingsOverviewViewState {
    public static let settingsOverviewReducer = Reducer.reduce { action, state in
        switch action {
        case .navigate(let navigationPath):
            state.navigationPath = navigationPath
        case .setNightMode(let isOn):
            state.isNightModeOn = isOn
        }
    }
}
