//
//  ElementsLoaderState+Wiring.swift
//  SatelliteForecast
//
//  Created by Ben Lu on 3/7/22.
//

import Foundation
import SatelliteForecastImpl

extension ElementsLoaderState: AppStateMappable {
    public static func project(appState: AppState) -> ElementsLoaderState {
        return ElementsLoaderState(
            resources: appState.elementsLoader,
            julianDateOffset: appState.debugMenu.effectiveOffset
        )
    }

    public static func apply(appState: inout AppState, state: ElementsLoaderState) {
        appState.elementsLoader = state.resources
    }
}
