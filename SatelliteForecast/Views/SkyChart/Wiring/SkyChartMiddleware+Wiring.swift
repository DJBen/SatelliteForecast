//
//  SkyChartMiddleware+Wiring.swift
//  SatelliteForecast
//
//  Created by Ben Lu on 3/30/22.
//

import CombineRex

extension EffectMiddleware where InputActionType == SkyChartAction, OutputActionType == SkyChartOutput, StateType == AppState, Dependencies == Void {
    func lift() -> AnyMiddleware<AppAction, AppAction, AppState> {
        lift(
            inputAction: \.skyChart,
            outputAction: AppAction.skyChartOutput
        )
        .eraseToAnyMiddleware()
    }
}
