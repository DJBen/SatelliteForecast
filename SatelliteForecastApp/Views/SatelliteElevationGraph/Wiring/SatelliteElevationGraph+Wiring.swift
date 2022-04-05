//
//  SatelliteElevationGraph+Wiring.swift
//  SatelliteForecast
//
//  Created by Ben Lu on 3/15/22.
//

import CombineRex
import CombineRextensions
import SatelliteForecast
import SatelliteForecastImpl

extension SatelliteElevationGraphState: AppStateMappable {
    static func project(
        appState: AppState
    ) -> SatelliteElevationGraphState {
        let selectedSatellitePass: Pass? = {
            guard let noradIndex = appState.navigationState.selectedNoradIndex,
                  let selectedPassIndex = appState.navigationState.listNavigation.selectedPassIndex else {
                return nil
            }

            return appState.elementsPropagatorResources.satelliteTrails[noradIndex]?.passSnapshots?[selectedPassIndex].pass
        }()

        return SatelliteElevationGraphState(
            currentJulianDate: appState.julianDate,
            satelliteElevationGraphResources: appState.satelliteElevationGraphResources,
            elementsPropagatorResources: appState.elementsPropagatorResources,
            selectedNoradIndex: appState.navigationState.selectedNoradIndex,
            highlightedDateRange: selectedSatellitePass.map { pass -> ClosedRange<Double> in
                return pass.rise.julianDate...pass.set.julianDate
            }
        )
    }

    static func apply(appState: inout AppState, state: SatelliteElevationGraphState) {
        appState.satelliteElevationGraphResources = state.satelliteElevationGraphResources
    }
}

extension ViewProducer where Context == SatelliteElevationGraphContext, ProducedView == SatelliteElevationGraph {
    static func satelliteElevationGraph<S: StoreType>(viewModel: S) -> ViewProducer where S.ActionType == AppAction, S.StateType == AppState {
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
