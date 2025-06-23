//
//  LocationMiddleware+RealtimeSky.swift
//  SatelliteForecastImplWiring
//
//  Created by Ben Lu on 4/20/22.
//

@preconcurrency import CombineRex
import SatelliteForecast

extension EffectMiddleware where InputActionType == LocationAction, OutputActionType == RealtimeSkyViewAction, StateType == Void, Dependencies == Void {
    /// This middleware triggers other `RealtimeSkyViewAction`s from location action.
    public static var locationToRealtimeSky: EffectMiddleware<LocationAction, RealtimeSkyViewAction, Void, Void> {
        EffectMiddleware.onAction { action, _, getState in
            switch action {
            case .selectLocation(_):
                return .just(.purgeElements)
            default:
                return .doNothing
            }
        }
    }

    public func lift() -> AnyMiddleware<AppAction, AppAction, AppState> {
        return lift(
            inputAction: \.location,
            outputAction: AppAction.realtimeSky,
            state: { _ in }
        )
        .eraseToAnyMiddleware()
    }
}
