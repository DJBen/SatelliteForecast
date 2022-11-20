//
//  DetailedPassViewReducer+Wiring.swift
//  SatelliteForecastImplWiring
//
//  Created by Ben Lu on 5/14/22.
//

import SwiftRex
import SatelliteForecast
import SatelliteForecastImpl

extension Reducer where ActionType == DetailedPassViewAction, StateType == DetailedPassViewState {
    public func lift() -> Reducer<AppAction, AppState> {
        lift(
            actionGetter: \.detailedPassView,
            stateGetter: DetailedPassViewState.project(appState:),
            stateSetter: DetailedPassViewState.apply(appState:state:)
        )
    }
}
