//
//  SatelliteOverviewReducer.swift
//  SatelliteForecast
//
//  Created by Ben Lu on 6/28/21.
//

import Foundation
import SwiftRex

extension Reducer where ActionType == SatelliteOverviewViewAction, StateType == SatelliteOverviewViewState {
    static let satelliteOverviewReducer = Reducer.reduce { action, state in
        switch action {
        case let .selectSpecialSatellite(params):
            state.navigationState.specialSatelliteNavigation.noradIndex = params.noradIndex
        case let .selectCategory(category):
            state.navigationState.listNavigation.category = category
        case .selectObserver:
            state.navigationState.observerNavigation.enabled = true
        case .selectAlert:
            state.navigationState.alarmNavigation.enabled = true
        case .returnToSatelliteOverview:
            state.navigationState.specialSatelliteNavigation = .init()
            state.navigationState.listNavigation = .init()
            state.navigationState.observerNavigation.enabled = false
            state.navigationState.alarmNavigation.enabled = false
        }
    }
}
