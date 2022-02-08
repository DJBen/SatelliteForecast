//
//  SatelliteListViewReducer.swift
//  SatelliteForecast
//
//  Created by Ben Lu on 6/5/21.
//

import Foundation
import SwiftRex

extension Reducer where ActionType == SatelliteListViewAction, StateType == AppState {
    static let satelliteListViewReducer = Reducer.reduce { action, state in
        switch action {
        case let .selectSatellite(params):
            state.navigationState.listNavigation.noradIndex = params?.noradIndex
        case let .satelliteSearchTextChanged(searchText):
            state.navigationState.listNavigation.satelliteSearchText = searchText
        case .retryLoadingSatelliteList:
            break
        }
    }
}
