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
        case .selectSatelliteOfSpecialInterest(let satellite, _, _):
            state.satellite = satellite
        case .selectCategory(let category, _, _):
            state.category = category
        }
    }
}
