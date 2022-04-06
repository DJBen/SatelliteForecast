//
//  RootView+Wiring.swift
//  SatelliteForecast
//
//  Created by Ben Lu on 3/5/22.
//

import CombineRex
import CombineRextensions

extension RootViewState: AppStateMappable {
    static func project(appState: AppState) -> RootViewState {
        RootViewState(
            selectedTab: appState.navigationState.tab
        )
    }

    static func apply(appState: inout AppState, state: RootViewState) {
        appState.navigationState.tab = state.selectedTab
    }
}

extension ViewProducer where Context == RootViewContext, ProducedView == RootView<RealtimeSkyViewImpl, SatelliteOverviewViewImpl, SettingsOverviewViewImpl> {
    static func root<S: StoreType>(
        viewModel: S
    ) -> ViewProducer where
    S.ActionType == AppAction,
    S.StateType == AppState {
        ViewProducer<Context, ProducedView> { context in
            RootView(
                viewModel: viewModel.projection(
                    action: AppAction.rootView,
                    state: RootViewState.project(appState:)
                )
                .asObservableViewModel(
                    initialState: .init(),
                    emitsValue: .whenDifferent
                ),
                context: context,
                realtimeSkyViewProducer: .realtimeSky(viewModel: viewModel),
                satelliteOverviewViewProducer: .satelliteOverview(viewModel: viewModel),
                settingsOverviewProducer: .settingsOverview(viewModel: viewModel)
            )
        }
    }
}
