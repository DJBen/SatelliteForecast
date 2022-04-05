//
//  SkyChartMiddleware+Wiring.swift
//  SatelliteForecast
//
//  Created by Ben Lu on 3/30/22.
//

import CombineRex
import SatelliteForecast
import SatelliteForecastImpl

extension EffectMiddleware where InputActionType == SkyChartAction, OutputActionType == SkyChartOutput, StateType == SkyChartViewState, Dependencies == Void {
    func lift() -> AnyMiddleware<AppAction, AppAction, AppState> {
        lift(
            inputAction: \.skyChart,
            outputAction: AppAction.skyChartOutput,
            state: SkyChartViewState.project(appState:)
        )
        .eraseToAnyMiddleware()
    }
}
