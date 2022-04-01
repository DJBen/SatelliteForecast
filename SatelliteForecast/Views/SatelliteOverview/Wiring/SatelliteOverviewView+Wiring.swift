//
//  SatelliteOverviewView+Wiring.swift
//  SatelliteForecast
//
//  Created by Ben Lu on 3/6/22.
//

import CombineRex
import CombineRextensions

extension SatelliteOverviewViewState: AppStateMappable {
    static func project(appState: AppState) -> SatelliteOverviewViewState {
        SatelliteOverviewViewState(
            navigationState: appState.navigationState,
            julianDate: appState.julianDate,
            location: appState.locationState.location
        )
    }

    static func apply(appState: inout AppState, state: SatelliteOverviewViewState) {
        appState.navigationState = state.navigationState
    }
}

extension ViewProducer where Context == Void, ProducedView == SatelliteOverviewViewImpl {
    static func satelliteOverview<S: StoreType>(viewModel: S) -> ViewProducer where S.ActionType == AppAction, S.StateType == AppState {
        ViewProducer<Context, ProducedView> { context in
            SatelliteOverviewViewImpl(
                viewModel: viewModel.projection(
                    action: AppAction.satelliteOverview,
                    state: SatelliteOverviewViewState.project(appState:)
                )
                .asObservableViewModel(initialState: .init(), emitsValue: .whenDifferent),
                listViewProducer: ViewProducer<SatelliteListViewContext, SatelliteListView>
                    .satelliteListView(viewModel: viewModel),
                singleSatelliteWrappingViewProducer: ViewProducer<SingleSatelliteWrappingViewContext, SingleSatelliteWrappingView>.singleSatelliteWrappingView(viewModel: viewModel)
            )
        }
    }
}
