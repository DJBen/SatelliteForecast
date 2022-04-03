//
//  SatelliteElevationGraph+Wiring.swift
//  SatelliteForecast
//
//  Created by Ben Lu on 3/15/22.
//

import SatelliteForecast

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
            highlightedDateRange: selectedSatellitePass.map { pass -> ClosedRange<Double> in
                return pass.rise.julianDate...pass.set.julianDate
            }
        )
    }

    static func apply(appState: inout AppState, state: SatelliteElevationGraphState) {
        appState.satelliteElevationGraphResources = state.satelliteElevationGraphResources
    }
}
