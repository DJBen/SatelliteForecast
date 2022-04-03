//
//  SatelliteElevationGraph+Wiring.swift
//  SatelliteForecast
//
//  Created by Ben Lu on 3/15/22.
//

import Foundation

extension SatelliteElevationGraphState: AppStateMappable {
    static func project(
        appState: AppState
    ) -> SatelliteElevationGraphState {
        return SatelliteElevationGraphState(
            currentJulianDate: appState.julianDate,
            satelliteElevationGraphResources: appState.satelliteElevationGraphResources,
            highlightedDateRange: appState.selectedSatellitePass.map { pass -> ClosedRange<Double> in
                return pass.rise.julianDate...pass.set.julianDate
            }
        )
    }

    static func apply(appState: inout AppState, state: SatelliteElevationGraphState) {
        appState.satelliteElevationGraphResources = state.satelliteElevationGraphResources
    }
}
