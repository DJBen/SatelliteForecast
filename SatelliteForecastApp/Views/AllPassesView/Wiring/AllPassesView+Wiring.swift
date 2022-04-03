//
//  AllPassesView+Wiring.swift
//  SatelliteForecast
//
//  Created by Ben Lu on 3/30/22.
//

import CombineRex
import CombineRextensions

extension AllPassesViewState: AppStateMappable {
    static func project(appState: AppState) -> AllPassesViewState {
        return AllPassesViewState(
            julianDate: appState.julianDate,
            scheduledPassNotifications: appState.notificationState.scheduledPassNotifications,
            skyChartResources: appState.skyChartResources,
            backgroundSkyResources: appState.backgroundSkyResources,
            location: appState.locationState.location,
            placemark: appState.locationState.placemark,
            selectedPassIndex: appState.navigationState.listNavigation.selectedPassIndex,
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
