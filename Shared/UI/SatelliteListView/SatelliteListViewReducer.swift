//
//  SatelliteListViewReducer.swift
//  SatelliteForecast
//
//  Created by Ben Lu on 6/5/21.
//

import Foundation
import SwiftRex

extension Reducer where ActionType == SatelliteListViewAction, StateType == Store.StateType {
    static let satelliteListViewReducer = Reducer.reduce { action, state in
        switch action {
        case let .selectSatellite(noradIndex):
            if let noradIndex = noradIndex {
                state.navigationState.selectSatellite(noradIndex: noradIndex)
            } else {
                state.navigationState.deselectSatellite()
            }

        case let .satelliteSearchTextChanged(searchText):
            state.satelliteSearchText = searchText

        case .retryLoadingSatelliteList:
            break
        }
    }
}
