//
//  AlarmSettingsView+Wiring.swift
//  SatelliteForecastImplWiring
//
//  Created by Ben Lu on 4/7/22.
//

@preconcurrency import CombineRex
@preconcurrency import CombineRextensions
import SatelliteForecastImpl

extension AlarmSettingsViewState: AppStateMappable {
    public static func project(appState: AppState) -> AlarmSettingsViewState {
        AlarmSettingsViewState(
            scheduledPassNotifications: appState.notificationResources.scheduledPassNotifications
            .sorted(by: { $0.notification.pass.rise.julianDate < $1.notification.pass.rise.julianDate })
        )
    }

    public static func apply(appState: inout AppState, state: AlarmSettingsViewState) {
        
    }
}

extension ViewProducer where Context == Void, ProducedView == AlarmSettingsView {
    public static func alarmSettingsView<S: StoreType>(viewModel: S) -> ViewProducer where S.ActionType == AppAction, S.StateType == AppState {
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
