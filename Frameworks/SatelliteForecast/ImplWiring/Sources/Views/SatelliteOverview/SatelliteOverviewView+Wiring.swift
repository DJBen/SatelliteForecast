//
//  SatelliteOverviewView+Wiring.swift
//  SatelliteForecast
//
//  Created by Ben Lu on 3/6/22.
//

@preconcurrency import CombineRex
@preconcurrency import CombineRextensions
@preconcurrency import SatelliteKit
import SatelliteForecastImpl

extension SatelliteOverviewViewState: AppStateMappable {
    public static func project(appState: AppState) -> SatelliteOverviewViewState {
        SatelliteOverviewViewState(
            navigationPath: appState.navigationState.passPredictionNavigationPath,
            observer: appState.locationResources.location.map(LatLonAlt.init),
            julianDateOffset: appState.debugMenu.effectiveOffset
        )
    }

    public static func apply(appState: inout AppState, state: SatelliteOverviewViewState) {
        appState.navigationState.passPredictionNavigationPath = state.navigationPath
    }
}

extension ViewProducer where Context == SatelliteOverviewViewContext, ProducedView == SatelliteOverviewViewImpl {
    public static func satelliteOverview<S: StoreType>(viewModel: S) -> ViewProducer where S.ActionType == AppAction, S.StateType == AppState {
        ViewProducer<Context, ProducedView> { context in
            SatelliteOverviewViewImpl(
                viewModel: viewModel.projection(
                    action: AppAction.satelliteOverview,
                    state: SatelliteOverviewViewState.project(appState:)
                )
                .asObservableViewModel(initialState: .init(), emitsValue: .whenDifferent),
                context: context,
                singleSatelliteWrappingViewProducer: ViewProducer<SingleSatelliteWrappingViewContext, SingleSatelliteWrappingView>.singleSatelliteWrappingView(viewModel: viewModel)
            )
        }
    }
}
