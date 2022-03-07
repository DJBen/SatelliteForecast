//
//  TLELoaderState+Wiring.swift
//  SatelliteForecast
//
//  Created by Ben Lu on 3/7/22.
//

import Foundation

extension TLELoaderState: AppStateMappable {
    static func project(appState: AppState) -> TLELoaderState {
        return TLELoaderState(
            resources: appState.tleLoader,
            currentDate: appState.currentDate
        )
    }

    static func apply(appState: inout AppState, state: TLELoaderState) {
        appState.tleLoader = state.resources
    }
}
