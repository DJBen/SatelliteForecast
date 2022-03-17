//
//  SatelliteOverviewView+Wiring.swift
//  SatelliteForecast
//
//  Created by Ben Lu on 3/6/22.
//

import Foundation

extension SatelliteOverviewViewState: AppStateMappable {
    static func project(appState: AppState) -> SatelliteOverviewViewState {
        SatelliteOverviewViewState(
            navigationState: appState.navigationState,
            julianDate: appState.julianDate,
            location: appState.locationState.location
        )
    }

    static func apply(appState: inout AppState, state: SatelliteOverviewViewState) {
        appState.navigationState = state.navigationState
    }
}
