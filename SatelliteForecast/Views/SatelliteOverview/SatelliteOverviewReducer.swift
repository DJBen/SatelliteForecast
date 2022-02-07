//
//  SatelliteOverviewReducer.swift
//  SatelliteForecast
//
//  Created by Ben Lu on 6/28/21.
//

import Foundation
import SwiftRex

extension Reducer where ActionType == SatelliteOverviewViewAction, StateType == AppState {
    static let satelliteOverviewReducer = Reducer.reduce { action, state in
        switch action {
        case let .selectSpecialSatellite(params):
            state.navigationState.selectSatellite(noradIndex: params.noradIndex)
        case let .selectCategory(category):
            state.navigationState.selectSatelliteCategory(category: category)
        case .selectObserver:
            state.navigationState.selectLocationSettings()
        case .selectAlert:
            state.navigationState.showAlertSettings()
        case .returnToSatelliteOverview:
            state.navigationState.returnToSatelliteOverview()
        }
    }
}
