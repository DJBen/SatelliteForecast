//
//  SatelliteElevationGraph+Wiring.swift
//  SatelliteForecast
//
//  Created by Ben Lu on 3/15/22.
//

@preconcurrency import CombineRex
@preconcurrency import CombineRextensions
import SatelliteForecast
import SatelliteForecastImpl

extension SatelliteElevationGraphState: AppStateMappable {
    public static func project(
        appState: AppState
    ) -> SatelliteElevationGraphState {
        return SatelliteElevationGraphState(
            satelliteElevationGraphResources: appState.satelliteElevationGraphResources,
            elementsPropagatorResources: appState.elementsPropagatorResources,
            julianDateOffset: appState.debugMenu.effectiveOffset
        )
    }

    public static func apply(appState: inout AppState, state: SatelliteElevationGraphState) {
        appState.satelliteElevationGraphResources = state.satelliteElevationGraphResources
    }
}

extension ViewProducer where Context == SatelliteElevationGraphContext, ProducedView == SatelliteElevationGraph {
    public static func satelliteElevationGraph<S: StoreType>(viewModel: S) -> ViewProducer where S.ActionType == AppAction, S.StateType == AppState {
        ViewProducer<Context, ProducedView> { context in
            SatelliteElevationGraph(
                viewModel: viewModel.projection(
                    action: AppAction.satelliteElevationGraph,
                    state:  SatelliteElevationGraphState.project(appState:)
                )
                .asObservableViewModel(initialState: .init(), emitsValue: .whenDifferent),
                context: context
            )
        }
    }
}
