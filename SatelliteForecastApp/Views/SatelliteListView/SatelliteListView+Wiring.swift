//
//  SatelliteListView+Wiring.swift
//  SatelliteForecastApp
//
//  Created by Ben Lu on 4/7/22.
//

import CombineRex
import CombineRextensions
import SatelliteForecastImpl

extension SatelliteListViewState: AppStateMappable {
    static func project(appState: AppState) -> SatelliteListViewState {
        return SatelliteListViewState(
            satelliteInfo: appState.elementsLoader.info,
            satelliteSearchText: appState.navigationState.listNavigation.satelliteSearchText,
            selectedNoradIndex: appState.navigationState.listNavigation.noradIndex
        )
    }

    static func apply(appState: inout AppState, state: SatelliteListViewState) {
        appState.navigationState.listNavigation.satelliteSearchText = state.satelliteSearchText
        appState.navigationState.listNavigation.noradIndex = state.selectedNoradIndex
    }
}

extension ViewProducer where Context == SatelliteListViewContext, ProducedView == SatelliteListView {
    static func satelliteListView<S: StoreType>(viewModel: S) -> ViewProducer where S.ActionType == AppAction, S.StateType == AppState {
        ViewProducer<Context, ProducedView> { context in
            SatelliteListView(
                viewModel: viewModel
                    .projection(
                        action: AppAction.satelliteListView,
                        state: SatelliteListViewState.project(appState:)
                    )
                    .asObservableViewModel(initialState: .init(), emitsValue: .whenDifferent),
                context: context,
                allPassesViewProducer: ViewProducer<AllPassesViewContext, AllPassesView>
                    .allPassesView(viewModel: viewModel)
            )
        }
    }
}
