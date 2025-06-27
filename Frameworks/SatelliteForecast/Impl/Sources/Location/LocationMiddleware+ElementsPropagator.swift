//
//  LocationMiddleware+Propagator.swift
//  SatelliteForecastImplWiring
//
//  Created by Ben Lu on 4/20/22.
//

@preconcurrency import CombineRex
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
}
