//
//  AlarmSettingsCell+Wiring.swift
//  SatelliteForecastImplWiring
//
//  Created by Ben Lu on 4/7/22.
//

@preconcurrency import CombineRex
@preconcurrency import CombineRextensions
import SatelliteForecast
import SatelliteForecastImpl

extension AlarmSettingsCellState: AppStateMappable {
    public static func project(appState: AppState) -> AlarmSettingsCellState {
        AlarmSettingsCellState(scheduledPassNotifications: appState.notificationResources.scheduledPassNotifications)
    }

    public static func apply(appState: inout AppState, state: AlarmSettingsCellState) {
        appState.notificationResources.scheduledPassNotifications = state.scheduledPassNotifications
    }
}

extension ViewProducer where Context == Void, ProducedView == AlarmSettingsCell {
    public static func alarmSettingsCell<S: StoreType>(viewModel: S) -> ViewProducer where S.ActionType == AppAction, S.StateType == AppState {
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
