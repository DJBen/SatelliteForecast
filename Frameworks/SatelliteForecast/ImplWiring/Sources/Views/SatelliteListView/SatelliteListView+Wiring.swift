//
//  SatelliteListView+Wiring.swift
//  SatelliteForecastImplWiring
//
//  Created by Ben Lu on 4/7/22.
//

@preconcurrency import CombineRex
@preconcurrency import CombineRextensions
import SatelliteForecastImpl

extension SatelliteListViewState: AppStateMappable {
    public static func project(appState: AppState) -> SatelliteListViewState {
        return SatelliteListViewState(
            navigationPath: appState.navigationState.passPredictionNavigationPath,
            satelliteInfo: appState.elementsLoader.info,
            filteredSatellites: appState.elementsLoader.filteredSatellites
        )
    }

    public static func apply(appState: inout AppState, state: SatelliteListViewState) {
        appState.navigationState.passPredictionNavigationPath = state.navigationPath
        appState.elementsLoader.filteredSatellites = state.filteredSatellites
    }
}

extension ViewProducer where Context == SatelliteListViewContext, ProducedView == SatelliteListView {
    public static func satelliteListView<S: StoreType>(viewModel: S) -> ViewProducer where S.ActionType == AppAction, S.StateType == AppState {
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
