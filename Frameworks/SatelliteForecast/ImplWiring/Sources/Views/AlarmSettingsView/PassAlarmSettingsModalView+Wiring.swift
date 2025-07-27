//
//  PassAlarmSettingsModalView+Wiring.swift
//  SatelliteForecastImplWiring
//
//  Created by Ben Lu on 4/21/22.
//

@preconcurrency import CombineRex
@preconcurrency import CombineRextensions
import SatelliteForecast
import SatelliteForecastImpl

extension PassAlarmSettingsModalViewState: AppStateMappable {
    public static func project(appState: AppState) -> PassAlarmSettingsModalViewState {
        PassAlarmSettingsModalViewState(
            scheduledPassNotifications: appState.notificationResources.scheduledPassNotifications,
            showAlarmConfigurationModal: appState.navigationState.listNavigation.showAlarmConfigurationModal
        )
    }

    public static func apply(appState: inout AppState, state: PassAlarmSettingsModalViewState) {
        appState.navigationState.listNavigation.showAlarmConfigurationModal = state.showAlarmConfigurationModal
    }
}

extension ViewProducer where Context == PassAlarmSettingsModalViewContext, ProducedView == PassAlarmSettingsModalView {
    public static func passAlarmSettings<S: StoreType>(viewModel: S) -> ViewProducer where S.ActionType == AppAction, S.StateType == AppState {
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

