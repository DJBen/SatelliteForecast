//
//  PassAlarmSettingsModalView+Wiring.swift
//  SatelliteForecastApp
//
//  Created by Ben Lu on 4/21/22.
//

import CombineRex
import CombineRextensions
import SatelliteForecastImpl

extension PassAlarmSettingsModalViewState: AppStateMappable {
    static func project(appState: AppState) -> PassAlarmSettingsModalViewState {
        PassAlarmSettingsModalViewState(
            scheduledPassNotifications: appState.notificationResources.scheduledPassNotifications,
            showAlarmConfigurationModal: appState.navigationState.listNavigation.showAlarmConfigurationModal
        )
    }

    static func apply(appState: inout AppState, state: PassAlarmSettingsModalViewState) {
        appState.navigationState.listNavigation.showAlarmConfigurationModal = state.showAlarmConfigurationModal
    }
}

extension ViewProducer where Context == PassAlarmSettingsModalViewContext, ProducedView == PassAlarmSettingsModalView {
    static func passAlarmSettings<S: StoreType>(viewModel: S) -> ViewProducer where S.ActionType == AppAction, S.StateType == AppState {
        ViewProducer<Context, ProducedView> { context in
            PassAlarmSettingsModalView(
                viewModel: viewModel
                    .projection(
                        action: AppAction.passAlarmSettings,
                        state: PassAlarmSettingsModalViewState.project(appState:)
                    )
                    .asObservableViewModel(initialState: .init(), emitsValue: .whenDifferent),
                context: context
            )
        }
    }
}

