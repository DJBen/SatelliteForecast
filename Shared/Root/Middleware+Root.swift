//
//  Middleware+Root.swift
//  SatelliteForecast
//
//  Created by Ben Lu on 7/13/21.
//

import Foundation
import CombineRex

extension MiddlewareReader where MiddlewareType == EffectMiddleware<SatelliteLoaderAction, AppAction, SatelliteLoaderState, SatelliteLoaderDependencies>, Dependencies == SatelliteLoaderDependencies {
    var lifted: MiddlewareReader<SatelliteLoaderDependencies, LiftMiddleware<AppAction, AppAction, AppState, EffectMiddleware<SatelliteLoaderAction, AppAction, SatelliteLoaderState, SatelliteLoaderDependencies>>> {
        return lift(
            inputAction: \AppAction.satelliteLoader,
            state: \AppState.satelliteLoaderState
        )
    }
}

extension LocationMiddleware {
    var lifted: AnyMiddleware<AppAction, AppAction, AppState> {
        return lift(
            inputAction: \AppAction.location,
            outputAction: AppAction.location,
            state: \AppState.locationState
        )
        .eraseToAnyMiddleware()
    }
}

extension EffectMiddleware where InputActionType == LocationAction, OutputActionType == Never, StateType == Void, Dependencies == Void {
    var lifted: AnyMiddleware<AppAction, AppAction, AppState> {
        return lift(
            inputAction: { $0.location },
            outputAction: { _ -> AppAction in },
            state: { _ in }
        )
        .eraseToAnyMiddleware()
    }
}

extension EffectMiddleware where InputActionType == DebugMenuAction, OutputActionType == AppAction, StateType == AppState, Dependencies == Void {
    var lifted: AnyMiddleware<AppAction, AppAction, AppState> {
        return lift(
            inputAction: { $0.debugMenu }
        )
        .eraseToAnyMiddleware()
    }
}
