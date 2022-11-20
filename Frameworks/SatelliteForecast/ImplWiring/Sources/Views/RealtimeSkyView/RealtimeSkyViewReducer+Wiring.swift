//
//  RealtimeSkyViewReducer+Wiring.swift
//  SatelliteForecast
//
//  Created by Ben Lu on 3/4/22.
//

import SwiftRex
import SatelliteForecast
import SatelliteForecastImpl

extension Reducer where ActionType == RealtimeSkyViewAction, StateType == RealtimeSkyViewResources {
    public func lift() -> Reducer<AppAction, AppState> {
        lift(
            actionGetter: \.realtimeSky,
            stateGetter: RealtimeSkyViewResources.project(appState:),
            stateSetter: RealtimeSkyViewResources.apply(appState:state:)
        )
    }
}

extension Reducer where ActionType == RealtimeSkyViewOutput, StateType == RealtimeSkyViewResources {
    public func lift() -> Reducer<AppAction, AppState> {
        lift(
            actionGetter: \.realtimeSkyOutput,
            stateGetter: RealtimeSkyViewResources.project(appState:),
            stateSetter: RealtimeSkyViewResources.apply(appState:state:)
        )
    }
}
