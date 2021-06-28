//
//  SatelliteOverviewReducer.swift
//  SatelliteForcast (iOS)
//
//  Created by Ben Lu on 6/28/21.
//

import Foundation
import SwiftRex

extension Reducer where ActionType == SatelliteOverviewViewAction, StateType == Store.StateType {
    static let satelliteOverviewReducer = Reducer.reduce { action, state in
        switch action {
        case let .selectSpecialSatellite(noradIndex):
            if let noradIndex = noradIndex {
                state.navigationState.selectNoradIndex(noradIndex)
            } else {
                state.navigationState.deselectNoradIndex()
            }
        case let .selectCategory(category):
            if let category = category {
                state.navigationState.selectCategory(category)
            } else {
                state.navigationState.deselectCategory()
            }
        }
    }
}
