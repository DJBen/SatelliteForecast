//
//  AlarmSettingsView+Wiring.swift
//  SatelliteForecastApp
//
//  Created by Ben Lu on 4/7/22.
//

import CombineRex
import CombineRextensions
import SatelliteForecastImpl

extension AlarmSettingsViewState: AppStateMappable {
    static func project(appState: AppState) -> AlarmSettingsViewState {
        AlarmSettingsViewState(
            notificationItems: appState.notificationResources.scheduledPassNotifications.compactMap { scheduledNotification -> Item? in
                return Item(
                    id: scheduledNotification.id,
                    passNotification: scheduledNotification.notification
                )
            }
            .sorted(by: { $0.passNotification.pass.rise.julianDate < $1.passNotification.pass.rise.julianDate })
        )
    }

    static func apply(appState: inout AppState, state: AlarmSettingsViewState) {
        
    }
}

extension ViewProducer where Context == Void, ProducedView == AlarmSettingsView {
    static func alarmSettingsView<S: StoreType>(viewModel: S) -> ViewProducer where S.ActionType == AppAction, S.StateType == AppState {
        ViewProducer<Context, ProducedView> { context in
            AlarmSettingsView(
                viewModel: viewModel
                    .projection(
                        action: AppAction.alarmSettingsView,
                        state: AlarmSettingsViewState.project(appState:)
                    )
                    .asObservableViewModel(initialState: .init(), emitsValue: .whenDifferent)
            )
        }
    }
}
