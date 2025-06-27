//
//  RootViewReducer.swift
//  SatelliteForecast
//
//  Created by Ben Lu on 3/6/22.
//

@preconcurrency import SwiftRex

extension Reducer where ActionType == RootViewAction, StateType == RootViewState {
    public static let rootViewReducer = Reducer.reduce { action, state in
        switch action {
        case .selectTab(let tab):
            state.selectedTab = tab
        }
    }
}
