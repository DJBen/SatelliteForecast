//
//  SatelliteListViewReducer.swift
//  SatelliteForcast
//
//  Created by Ben Lu on 6/5/21.
//

import Foundation
import SwiftRex

extension Reducer where ActionType == SatelliteListViewAction, StateType == Store.StateType {
    static let satelliteListViewReducer = Reducer.reduce { action, state in
        switch action {
        case let .selectSatellite(noradIndex: noradIndex):
            if let noradIndex = noradIndex {
                state.navigationState.selectNoradIndex(noradIndex)
            } else {
                state.navigationState.deselectNoradIndex()
            }

        case let .satelliteSearchTextChanged(searchText):
            state.satelliteSearchText = searchText

        case .retryLoadingSatelliteList:
            break
        }
    }
}
