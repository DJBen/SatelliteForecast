//
//  DebugMenuReducer.swift
//  SatelliteForecast
//
//  Created by Ben Lu on 7/25/21.
//

import Foundation
import SatelliteForecastImpl
@preconcurrency import SwiftRex

extension Reducer where ActionType == DebugMenuAction, StateType == DebugMenuState {
    public func lift() -> Reducer<AppAction, AppState> {
        lift(
            actionGetter: \.debugMenu,
            stateGetter: DebugMenuState.project(appState:),
            stateSetter: DebugMenuState.apply(appState:state:)
        )
    }
}

extension MiddlewareReader where MiddlewareType == DebugMenuEffectMiddleware, Dependencies == DebugMenuMiddlewareDependencies {
    public func lift(dependencies: DebugMenuMiddlewareDependencies) -> AnyMiddleware<AppAction, AppAction, AppState> {
        lift(
            inputAction: \.debugMenu
        )
        .inject(
            dependencies
        )
        .eraseToAnyMiddleware()
    }
}
