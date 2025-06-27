//
//  SatelliteCategoryReducer+Wiring.swift
//  SatelliteForecast
//
//  Created by Ben Lu on 3/6/22.
//

@preconcurrency import SwiftRex
import SatelliteForecast
import SatelliteForecastImpl

extension Reducer where ActionType == SatelliteCategoryViewAction, StateType == SatelliteCategoryViewState {
    public func lift() -> Reducer<AppAction, AppState> {
        lift(
            actionGetter: \.satelliteCategory,
            stateGetter: SatelliteCategoryViewState.project(appState:),
            stateSetter: SatelliteCategoryViewState.apply(appState:state:)
        )
    }
}
