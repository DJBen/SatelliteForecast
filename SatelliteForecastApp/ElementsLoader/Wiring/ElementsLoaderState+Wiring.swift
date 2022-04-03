//
//  ElementsLoaderState+Wiring.swift
//  SatelliteForecast
//
//  Created by Ben Lu on 3/7/22.
//

import Foundation
import SatelliteForecastImpl

extension ElementsLoaderState: AppStateMappable {
    static func project(appState: AppState) -> ElementsLoaderState {
        return ElementsLoaderState(
            resources: appState.elementsLoader,
            currentDate: appState.currentDate
        )
    }

    static func apply(appState: inout AppState, state: ElementsLoaderState) {
        appState.elementsLoader = state.resources
        if appState.realtimeSkyResources.results.isEmpty {

        }
    }
}
