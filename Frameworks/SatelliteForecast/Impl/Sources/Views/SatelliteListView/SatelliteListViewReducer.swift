//
//  SatelliteListViewReducer.swift
//  SatelliteForecast
//
//  Created by Ben Lu on 6/5/21.
//

import SwiftRex

extension Reducer where ActionType == SatelliteListViewAction, StateType == SatelliteListViewState {
    public static let satelliteListViewReducer = Reducer.reduce { action, state in
        switch action {
        case .selectSatellite(let params):
            break
        case .loadSatellite(let params):
            break
        case let .satelliteSearchTextChanged(searchText):
            state.satelliteSearchText = searchText
        case .retryLoadingSatelliteList:
            break
        }
    }
}
