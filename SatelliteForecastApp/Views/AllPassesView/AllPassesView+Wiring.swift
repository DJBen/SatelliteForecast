//
//  AllPassesView+Wiring.swift
//  SatelliteForecast
//
//  Created by Ben Lu on 3/30/22.
//

import CombineRex
import CombineRextensions
import SatelliteForecastImpl

extension AllPassesViewState: AppStateMappable {
    static func project(appState: AppState) -> AllPassesViewState {
        return AllPassesViewState(
            julianDateOffset: appState.debugMenu.effectiveOffset,
            scheduledPassNotifications: appState.notificationResources.scheduledPassNotifications,
            skyChartResources: appState.skyChartResources,
            backgroundSkyResources: appState.backgroundSkyResources,
            location: appState.locationResources.location,
            placemark: appState.locationResources.placemark,
            selectedPassIndex: appState.navigationState.listNavigation.selectedPassIndex,
            showsPassAlarmSettingsModal: appState.navigationState.listNavigation.showAlarmConfigurationModal,
            satelliteCategory: appState.navigationState.listNavigation.category,
            satelliteTrails: appState.elementsPropagatorResources.satelliteTrails
        )
    }

    static func apply(appState: inout AppState, state: AllPassesViewState) {
        appState.navigationState.listNavigation.selectedPassIndex = state.selectedPassIndex
        appState.navigationState.listNavigation.category = state.satelliteCategory
    }
}

extension ViewProducer where Context == AllPassesViewContext, ProducedView == AllPassesView {
    static func allPassesView<S: StoreType>(viewModel: S) -> ViewProducer where S.ActionType == AppAction, S.StateType == AppState {
        ViewProducer<Context, ProducedView> { context in
            AllPassesView(
                viewModel: viewModel
                    .projection(
                        action: { AppAction.allPassesView($0) },
                        state: AllPassesViewState.project(appState:)
                    )
                    .asObservableViewModel(initialState: .init(), emitsValue: .whenDifferent),
                context: context,
                skyChartProducer: ViewProducer<SkyChartContext, SkyChart>
                    .skyChart(viewModel: viewModel),
                passViewProducer: ViewProducer<PassViewContext, PassView>
                    .passView(viewModel: viewModel)
            )
        }
    }
}
