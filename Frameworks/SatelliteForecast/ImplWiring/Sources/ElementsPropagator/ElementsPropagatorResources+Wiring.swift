//
//  ElementsPropagatorResources+Wiring.swift
//  SatelliteForecastImplWiring
//
//  Created by Ben Lu on 4/2/22.
//

import SatelliteForecast
import SatelliteForecastImpl

extension ElementsPropagatorResources: AppStateMappable {
    public static func project(appState: AppState) -> ElementsPropagatorResources {
        appState.elementsPropagatorResources
    }

    public static func apply(appState: inout AppState, state: ElementsPropagatorResources) {
        appState.elementsPropagatorResources = state
    }
}
