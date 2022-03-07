//
//  SatelliteLoaderState+Wiring.swift
//  SatelliteForecast
//
//  Created by Ben Lu on 3/7/22.
//

import Foundation

extension SatelliteLoaderState: AppStateMappable {
    static func project(appState: AppState) -> SatelliteLoaderState {
        return SatelliteLoaderState(
            resources: appState.satelliteLoader,
            currentDate: appState.currentDate
        )
    }

    static func apply(appState: inout AppState, state: SatelliteLoaderState) {
        appState.satelliteLoader = state.resources
    }
}
