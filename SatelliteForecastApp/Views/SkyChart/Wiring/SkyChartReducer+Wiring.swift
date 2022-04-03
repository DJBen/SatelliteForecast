//
//  SkyChartReducer+Wiring.swift
//  SatelliteForecast
//
//  Created by Ben Lu on 3/30/22.
//

import SwiftRex

extension Reducer where ActionType == SkyChartOutput, StateType == SkyChartViewState {
    func lift() -> Reducer<AppAction, AppState> {
        lift(
            actionGetter: \.skyChartOutput,
            stateGetter: SkyChartViewState.project(appState:),
            stateSetter: SkyChartViewState.apply(appState:state:)
        )
    }
}
