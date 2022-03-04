//
//  BackgroundSkyView+Wiring.swift
//  SatelliteForecast
//
//  Created by Ben Lu on 3/4/22.
//

import CombineRex
import CombineRextensions

extension BackgroundSkyViewState: AppStateMappable {
    static func project(appState: AppState) -> BackgroundSkyViewState {
        BackgroundSkyViewState(
            resources: appState.backgroundSkyResources
        )
    }

    static func apply(appState: inout AppState, state: BackgroundSkyViewState) {
        appState.backgroundSkyResources = state.resources
    }
}

extension ViewProducer where Context == BackgroundSkyViewContext, ProducedView == BackgroundSkyView {
    static func backgroundSky<S: StoreType>(
        viewModel: S
    ) -> ViewProducer where
    S.ActionType == AppAction,
    S.StateType == AppState {
        ViewProducer<Context, ProducedView> { context in
            BackgroundSkyView(
                viewModel: viewModel.projection(
                    action: AppAction.backgroundSky,
                    state: BackgroundSkyViewState.project(appState:)
                )
                    .asObservableViewModel(
                        initialState: .init(),
                        emitsValue: .whenDifferent
                    ),
                context: context
            )
        }
    }
}
