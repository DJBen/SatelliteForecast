//
//  SettingsOverviewReducer.swift
//  SatelliteForecast
//
//  Created by Ben Lu on 3/30/22.
//

import Foundation
import SwiftRex

extension Reducer where ActionType == SettingsOverviewViewAction, StateType == SettingsOverviewViewState {
    static let settingsOverviewReducer = Reducer.reduce { action, state in
        switch action {
        case let .selectSettingItem(item):
            if let item = item {
                switch item {
                case .observer:
                    state.observerNavigation.enabled = true
                case .alarms:
                    state.alarmNavigation.enabled = true
                }
            } else {
                state.observerNavigation.enabled = false
                state.alarmNavigation.enabled = false
            }
        }
    }
}
