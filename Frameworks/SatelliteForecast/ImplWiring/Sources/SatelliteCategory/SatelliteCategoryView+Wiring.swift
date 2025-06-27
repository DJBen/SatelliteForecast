//
//  SatelliteCategoryView+Wiring.swift
//  SatelliteForecastPackage
//
//  Created by Sihao Lu on 6/27/25.
//

@preconcurrency import CombineRex
@preconcurrency import CombineRextensions
@preconcurrency import SatelliteKit
import SatelliteForecastImpl

extension SatelliteCategoryViewState: AppStateMappable {
    public static func project(appState: AppState) -> SatelliteCategoryViewState {
        SatelliteCategoryViewState(
            navigationPath: appState.navigationState.satelliteCategoryNavigationPath,
            observer: appState.locationResources.location.map(LatLonAlt.init),
            julianDateOffset: appState.debugMenu.effectiveOffset
        )
    }

    public static func apply(appState: inout AppState, state: SatelliteCategoryViewState) {
        appState.navigationState.satelliteCategoryNavigationPath = state.navigationPath
    }
}

extension ViewProducer where Context == SatelliteCategoryViewContext, ProducedView == SatelliteCategoryViewImpl {
    public static func satelliteCategory<S: StoreType>(viewModel: S) -> ViewProducer where S.ActionType == AppAction, S.StateType == AppState {
        ViewProducer<Context, ProducedView> { context in
            SatelliteCategoryViewImpl(
                viewModel: viewModel.projection(
                    action: AppAction.satelliteCategory,
                    state: SatelliteCategoryViewState.project(appState:)
                )
                .asObservableViewModel(initialState: .init(), emitsValue: .whenDifferent),
                context: context,
                listViewProducer: ViewProducer<SatelliteListViewContext, SatelliteListView>
                    .satelliteListView(viewModel: viewModel),
            )
        }
    }
}
