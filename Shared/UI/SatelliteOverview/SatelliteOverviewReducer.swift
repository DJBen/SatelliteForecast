//
//  SatelliteOverviewReducer.swift
//  SatelliteForecast
//
//  Created by Ben Lu on 6/28/21.
//

import Foundation
import SwiftRex

extension Reducer where ActionType == SatelliteOverviewViewAction, StateType == Store.StateType {
    static let satelliteOverviewReducer = Reducer.reduce { action, state in
        switch action {
        case let .selectSpecialSatellite(noradIndex):
            state.navigationState.selectNoradIndex(noradIndex)
        case let .selectCategory(category):
            state.navigationState.selectCategory(category)
        case .selectObserver:
            state.navigationState.selectObserver()
        case .selectAlert:
            break
        case .returnToSatelliteOverview:
            state.navigationState.deselectSatelliteOverviewItem()
        }
    }
}
