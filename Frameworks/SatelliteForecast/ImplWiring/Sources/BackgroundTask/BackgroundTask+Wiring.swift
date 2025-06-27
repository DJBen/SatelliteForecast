//
//  BackgroundTask+Wiring.swift
//  BackgroundTaskMiddleware
//
//  Created by Ben Lu on 8/19/21.
//

import Combine
@preconcurrency import CombineRex
import SatelliteForecastImpl
import Foundation

extension EffectMiddleware where
    InputActionType == BackgroundTask,
    OutputActionType == AppAction,
    StateType == AppState,
    Dependencies == Void {

    public func lift() -> AnyMiddleware<AppAction, AppAction, AppState> {
        return lift(
            inputAction: \.backgroundTask
        )
        .eraseToAnyMiddleware()
    }
}
