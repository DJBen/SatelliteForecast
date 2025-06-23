//
//  SkyChartMiddleware+Wiring.swift
//  SatelliteForecast
//
//  Created by Ben Lu on 3/30/22.
//

@preconcurrency import CombineRex
import SatelliteForecast
import SatelliteForecastImpl

extension EffectMiddleware where InputActionType == SkyChartAction, OutputActionType == SkyChartOutput, StateType == SkyChartViewState, Dependencies == Void {
    public func lift() -> AnyMiddleware<AppAction, AppAction, AppState> {
        lift(
            inputAction: \.skyChart,
            outputAction: AppAction.skyChartOutput,
            state: SkyChartViewState.project(appState:)
        )
        .eraseToAnyMiddleware()
    }
}
