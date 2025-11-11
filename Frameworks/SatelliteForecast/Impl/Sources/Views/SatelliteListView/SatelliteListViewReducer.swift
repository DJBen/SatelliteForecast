//
//  SatelliteListViewReducer.swift
//  SatelliteForecast
//
//  Created by Ben Lu on 6/5/21.
//

@preconcurrency import SwiftRex
import SatelliteForecast

extension Reducer where ActionType == SatelliteListViewAction, StateType == SatelliteListViewState {
    public static let satelliteListViewReducer = Reducer.reduce { action, state in
        switch action {
        case .selectSatellite(let params, let category):
            state.navigationPath.append(category)
            state.navigationPath.append(SatelliteListSelectedSatellite(noradIndex: params.noradIndex))
        case .loadSatellite(let params):
            break
        case .retryLoadingSatelliteList:
            break
        case .reloadSatellites:
            break
        case .searchSatellites(_, category: _):
            break
        }
    }
}

extension Reducer where ActionType == SatelliteListViewOutput, StateType == SatelliteListViewState {
    public static let satelliteListOutputReducer = Reducer.reduce { action, state in
        switch action {
        case .filteredSatellites(let filteredSatellites, searchText: let searchText, category: let category):
            state.filteredSatellites = filteredSatellites
        }
    }
}
