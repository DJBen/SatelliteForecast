//
//  DetailedPassView.swift
//  SatelliteForecastImplWiring
//
//  Created by Ben Lu on 5/3/22.
//

@preconcurrency import CombineRex
@preconcurrency import CombineRextensions
import SatelliteForecast
import SatelliteForecastImpl

extension DetailedPassViewState: AppStateMappable {
    public static func project(appState: AppState) -> DetailedPassViewState {
        DetailedPassViewState(
            showsDetailedPassView: appState.navigationState.listNavigation.showsDetailPassView
        )
    }

    public static func apply(appState: inout AppState, state: DetailedPassViewState) {
        appState.navigationState.listNavigation.showsDetailPassView = state.showsDetailedPassView
    }
}

extension ViewProducer where Context == DetailPassViewContext, ProducedView == DetailedPassView {
    public static func detailedPassView<S: StoreType>(
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
