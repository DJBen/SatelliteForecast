//
//  SatelliteOverviewReducer.swift
//  SatelliteForecast
//
//  Created by Ben Lu on 6/28/21.
//

import Foundation
@preconcurrency import SwiftRex

extension Reducer where ActionType == SatelliteOverviewViewAction, StateType == SatelliteOverviewViewState {
    public static let satelliteOverviewReducer = Reducer.reduce { action, state in
        switch action {
        case .navigate(let navigationPath):
            state.navigationPath = navigationPath
        case .onAppear:
            break
        case .selectSatellite(let satellite, julianDateRange: _, observer: _):
            state.navigationPath.append(satellite)
        }
    }
}
