//
//  SatelliteCategoryReducer.swift
//  SatelliteForecast
//
//  Created by Ben Lu on 6/27/25.
//

import Foundation
@preconcurrency import SwiftRex
import SatelliteForecast

extension Reducer where ActionType == SatelliteCategoryViewAction, StateType == SatelliteCategoryViewState {
    public static let satelliteCategoryReducer = Reducer.reduce { action, state in
        switch action {
        case .navigate(let navigationPath):
            state.navigationPath = navigationPath
        case .loadCategory(_, julianDateRange: _, observer: _):
            break
        }
    }
}
