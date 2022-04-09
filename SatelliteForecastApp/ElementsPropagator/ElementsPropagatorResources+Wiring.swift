//
//  ElementsPropagatorResources+Wiring.swift
//  SatelliteForecastApp
//
//  Created by Ben Lu on 4/2/22.
//

import SatelliteForecast
import SatelliteForecastImpl

extension ElementsPropagatorResources: AppStateMappable {
    static func project(appState: AppState) -> ElementsPropagatorResources {
        appState.elementsPropagatorResources
    }

    static func apply(appState: inout AppState, state: ElementsPropagatorResources) {
        appState.elementsPropagatorResources = state
    }
}
