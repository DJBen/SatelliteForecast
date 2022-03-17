//
//  RealtimeSkyViewMiddleware+Wiring.swift
//  SatelliteForecast
//
//  Created by Ben Lu on 3/4/22.
//

import CombineRex

extension EffectMiddleware where InputActionType == RealtimeSkyViewAction, OutputActionType == RealtimeSkyViewOutput, StateType == RealtimeSkyViewResources, Dependencies == Void {
    func lift() -> AnyMiddleware<AppAction, AppAction, AppState> {
        lift(
            inputAction: \.realtimeSky,
            outputAction: AppAction.realtimeSkyOutput,
            state: RealtimeSkyViewResources.project(appState:)
        )
        .eraseToAnyMiddleware()
    }
}
