//
//  SatelliteOverviewView+Wiring.swift
//  SatelliteForecast
//
//  Created by Ben Lu on 3/6/22.
//

import CombineRex
import CombineRextensions
import SatelliteKit
import SatelliteForecastImpl

extension SatelliteOverviewViewState: AppStateMappable {
    static func project(appState: AppState) -> SatelliteOverviewViewState {
        SatelliteOverviewViewState(
            navigationPath: appState.navigationState.passPredictionNavigationPath,
            observer: appState.locationResources.location.map(LatLonAlt.init),
            julianDateOffset: appState.debugMenu.effectiveOffset
        )
    }

    static func apply(appState: inout AppState, state: SatelliteOverviewViewState) {
        appState.navigationState.passPredictionNavigationPath = state.navigationPath
    }
}

extension ViewProducer where Context == SatelliteOverviewViewContext, ProducedView == SatelliteOverviewViewImpl {
    static func satelliteOverview<S: StoreType>(viewModel: S) -> ViewProducer where S.ActionType == AppAction, S.StateType == AppState {
        ViewProducer<Context, ProducedView> { context in
            SatelliteOverviewViewImpl(
                viewModel: viewModel.projection(
                    action: AppAction.satelliteOverview,
                    state: SatelliteOverviewViewState.project(appState:)
                )
                .asObservableViewModel(initialState: .init(), emitsValue: .whenDifferent),
                context: context,
                listViewProducer: ViewProducer<SatelliteListViewContext, SatelliteListView>
                    .satelliteListView(viewModel: viewModel),
                singleSatelliteWrappingViewProducer: ViewProducer<SingleSatelliteWrappingViewContext, SingleSatelliteWrappingView>.singleSatelliteWrappingView(viewModel: viewModel)
            )
        }
    }
}
