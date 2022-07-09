//
//  DetailedPassView.swift
//  SatelliteForecastApp
//
//  Created by Ben Lu on 5/3/22.
//

import CombineRex
import CombineRextensions
import SatelliteForecastImpl

extension DetailedPassViewState: AppStateMappable {
    static func project(appState: AppState) -> DetailedPassViewState {
        DetailedPassViewState(
            showsDetailedPassView: appState.navigationState.listNavigation.showsDetailPassView
        )
    }

    static func apply(appState: inout AppState, state: DetailedPassViewState) {
        appState.navigationState.listNavigation.showsDetailPassView = state.showsDetailedPassView
    }
}

extension ViewProducer where Context == DetailPassViewContext, ProducedView == DetailedPassView {
    static func detailedPassView<S: StoreType>(
        viewModel: S
    ) -> ViewProducer where
    S.ActionType == AppAction,
    S.StateType == AppState {
        ViewProducer<Context, ProducedView> { context in
            DetailedPassView(
                viewModel: viewModel.projection(
                    action: AppAction.detailedPassView,
                    state: DetailedPassViewState.project(appState:)
                )
                .asObservableViewModel(initialState: .init(), emitsValue: .whenDifferent),
                context: context,
                skyChartProducer: .skyChartForDetailedView(viewModel: viewModel)
            )
        }
    }
}
