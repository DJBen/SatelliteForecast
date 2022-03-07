//
//  RootViewReducer.swift
//  SatelliteForecast
//
//  Created by Ben Lu on 3/6/22.
//

import SwiftRex

extension Reducer where ActionType == RootViewAction, StateType == RootViewState {
    static let rootViewReducer = Reducer.reduce { action, state in
        switch action {
        case .selectTab(let tab):
            state.selectedTab = tab
        }
    }
}
