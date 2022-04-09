//
//  AlarmSettingsCell+Wiring.swift
//  SatelliteForecastApp
//
//  Created by Ben Lu on 4/7/22.
//

import CombineRex
import CombineRextensions
import SatelliteForecastImpl

extension AlarmSettingsCellState: AppStateMappable {
    static func project(appState: AppState) -> AlarmSettingsCellState {
        AlarmSettingsCellState(scheduledPassNotifications: appState.notificationResources.scheduledPassNotifications)
    }

    static func apply(appState: inout AppState, state: AlarmSettingsCellState) {
        appState.notificationResources.scheduledPassNotifications = state.scheduledPassNotifications
    }
}

extension ViewProducer where Context == Void, ProducedView == AlarmSettingsCell {
    static func alarmSettingsCell<S: StoreType>(viewModel: S) -> ViewProducer where S.ActionType == AppAction, S.StateType == AppState {
        ViewProducer<Context, ProducedView> { context in
            AlarmSettingsCell(
                viewModel: viewModel.projection(
                    action: AppAction.alarmSettingsCell,
                    state: AlarmSettingsCellState.project(appState:)
                )
                .asObservableViewModel(initialState: .init(), emitsValue: .whenDifferent)
            )
        }
    }
}
