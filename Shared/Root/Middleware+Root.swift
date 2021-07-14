//
//  Middleware+Root.swift
//  SatelliteForcast (iOS)
//
//  Created by Ben Lu on 7/13/21.
//

import Foundation
import CombineRex

extension MiddlewareReader where MiddlewareType == EffectMiddleware<SatelliteLoaderAction, SatelliteLoaderAction, SatelliteLoaderState, SatelliteLoaderDependencies>, Dependencies == SatelliteLoaderDependencies {
    var lifted: MiddlewareReader<SatelliteLoaderDependencies, LiftMiddleware<AppAction, AppAction, AppState, EffectMiddleware<SatelliteLoaderAction, SatelliteLoaderAction, SatelliteLoaderState, SatelliteLoaderDependencies>>> {
        return lift(
            inputAction: \AppAction.satelliteLoader,
            outputAction: AppAction.satelliteLoader,
            state: \AppState.satelliteLoaderState
        )
    }
}

extension CoreLocationMiddleware {
    var lifted: AnyMiddleware<AppAction, AppAction, AppState> {
        return lift(
            inputAction: { $0.coreLocation },
            outputAction: AppAction.coreLocation,
            state: \AppState.coreLocationState
        )
        .eraseToAnyMiddleware()
    }
}

extension EffectMiddleware where InputActionType == CoreLocationAction, OutputActionType == Never, StateType == Void, Dependencies == Void {
    var lifted: AnyMiddleware<AppAction, AppAction, AppState> {
        return lift(
            inputAction: { $0.coreLocation },
            outputAction: { _ -> AppAction in },
            state: { _ in }
        )
        .eraseToAnyMiddleware()
    }
}
