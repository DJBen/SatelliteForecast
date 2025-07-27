//
//  LocationState+Wiring.swift
//  SatelliteForecastImplWiring
//
//  Created by Ben Lu on 4/4/22.
//

import SatelliteForecast
import SatelliteForecastImpl

extension LocationState: AppStateMappable {
    public static func project(appState: AppState) -> LocationState {
        LocationState(
            resources: appState.locationResources,
            navigationPath: appState.navigationState.settingsNavigationPath,
            fcmToken: appState.fcmToken,
        )
    }

    public static func apply(appState: inout AppState, state: LocationState) {
        appState.locationResources = state.resources
        appState.navigationState.settingsNavigationPath = state.navigationPath
    }
}
