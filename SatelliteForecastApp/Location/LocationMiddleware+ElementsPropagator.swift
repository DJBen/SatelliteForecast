//
//  LocationMiddleware+Propagator.swift
//  SatelliteForecastApp
//
//  Created by Ben Lu on 4/20/22.
//

import CombineRex
import SatelliteForecast

extension EffectMiddleware where InputActionType == LocationAction, OutputActionType == ElementsPropagatorAction, StateType == Void, Dependencies == Void {
    /// This middleware triggers other `ElementsPropagatorAction`s from location action.
    public static var locationToElementsPropagator: EffectMiddleware<LocationAction, ElementsPropagatorAction, Void, Void> {
        EffectMiddleware.onAction { action, _, getState in
            switch action {
            case .selectLocation(_):
                return .just(.purgePassesAndSnapshots)
            default:
                return .doNothing
            }
        }
    }

    func lift() -> AnyMiddleware<AppAction, AppAction, AppState> {
        return lift(
            inputAction: \.location,
            outputAction: AppAction.elementsPropagator,
            state: { _ in }
        )
        .eraseToAnyMiddleware()
    }
}
