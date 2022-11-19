//
//  SatelliteOverviewReducer.swift
//  SatelliteForecast
//
//  Created by Ben Lu on 6/28/21.
//

import Foundation
import SwiftRex

extension Reducer where ActionType == SatelliteOverviewViewAction, StateType == SatelliteOverviewViewState {
    public static let satelliteOverviewReducer = Reducer.reduce { action, state in
        switch action {
        case .navigate(let navigationPath, julianDateRange: _, observer: _):
            state.path = navigationPath
        case .selectSatelliteOfSpecialInterest(let satellite, julianDateRange: _, observer: _):
            state.path.append(satellite)
        case .loadCategory(_, julianDateRange: _, observer: _):
            break
        case .loadSatelliteOfSpecialInterest(_, julianDateRange: _, observer: _):
            break
        }
    }
}
