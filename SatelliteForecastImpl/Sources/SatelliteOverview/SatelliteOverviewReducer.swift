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
        case .selectNavigationItem(let item, _, _):
            state.selectedSatelliteOverviewItem = item
        }
    }
}
