//
//  SettingsOverviewView+Wiring.swift
//  SatelliteForecast
//
//  Created by Ben Lu on 3/19/22.
//

import CombineRex
import CombineRextensions
import SatelliteForecast
import SatelliteForecastImpl

extension SettingsOverviewViewState: AppStateMappable {
    public static func project(appState: AppState) -> SettingsOverviewViewState {
        SettingsOverviewViewState(
            navigationPath: appState.navigationState.settingsNavigationPath
        )
    }

    public static func apply(appState: inout AppState, state: SettingsOverviewViewState) {
        appState.navigationState.settingsNavigationPath = state.navigationPath
    }
}

extension ViewProducer where Context == Void, ProducedView == SettingsOverviewViewImpl {
    public static func settingsOverview<S: StoreType>(
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
