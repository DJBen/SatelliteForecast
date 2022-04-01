//
//  SettingsOverviewView+Wiring.swift
//  SatelliteForecast
//
//  Created by Ben Lu on 3/19/22.
//

import CombineRex
import CombineRextensions

extension SettingsOverviewViewState: AppStateMappable {
    static func project(appState: AppState) -> SettingsOverviewViewState {
        SettingsOverviewViewState(
            observerNavigation: appState.navigationState.observerNavigation,
            alarmNavigation: appState.navigationState.alarmNavigation
        )
    }

    static func apply(appState: inout AppState, state: SettingsOverviewViewState) {
        appState.navigationState.observerNavigation = state.observerNavigation
        appState.navigationState.alarmNavigation = state.alarmNavigation
    }
}

extension ViewProducer where Context == Void, ProducedView == SettingsOverviewViewImpl {
    static func settingsOverview<S: StoreType>(
        viewModel: S
    ) -> ViewProducer where
    S.ActionType == AppAction,
    S.StateType == AppState {
        ViewProducer<Context, ProducedView> { context in
            SettingsOverviewViewImpl(
                viewModel: viewModel.projection(
                    action: AppAction.settingsOverview,
                    state: SettingsOverviewViewState.project(appState:)
                )
                .asObservableViewModel(initialState: .init(), emitsValue: .whenDifferent),
                observerCellViewProducer: .observerCell(viewModel: viewModel),
                locationSettingsViewProducer: .locationSettings(viewModel: viewModel),
                alarmSettingsCellProducer: .alarmSettingsCell(viewModel: viewModel),
                alarmSettingsViewProducer: .alarmSettingsView(viewModel: viewModel)
            )
        }
    }
}
