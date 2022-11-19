//
//  LocationState+Wiring.swift
//  SatelliteForecastApp
//
//  Created by Ben Lu on 4/4/22.
//

import SatelliteForecastImpl

extension LocationState: AppStateMappable {
    static func project(appState: AppState) -> LocationState {
        LocationState(
            resources: appState.locationResources,
            navigationPath: appState.navigationState.settingsNavigationPath
        )
    }

    static func apply(appState: inout AppState, state: LocationState) {
        appState.locationResources = state.resources
        appState.navigationState.settingsNavigationPath = state.navigationPath
    }
}
