//
//  AllPassesViewMiddleware+ElementsPropagator.swift
//  SatelliteForecastImplWiring
//
//  Created by Ben Lu on 4/4/22.
//

@preconcurrency import CombineRex
import SatelliteForecast

extension EffectMiddleware where InputActionType == AllPassesViewAction, OutputActionType == ElementsPropagatorAction, StateType == Void, Dependencies == Void {
    public static var allPassesViewToElementsPropagator: EffectMiddleware<AllPassesViewAction, ElementsPropagatorAction, Void, Void> {
        EffectMiddleware<AllPassesViewAction, ElementsPropagatorAction, Void, Void>.onAction { (action, _, getState) -> Effect<Void, ElementsPropagatorAction> in
            switch action {
            case .calculatePasses(let calculatePassesParams):
                return .just(.calculatePasses(calculatePassesParams))
            case .recalculatePasses(let calculatePassesParams):
                return .just(.recalculatePasses(calculatePassesParams))
            case .scheduleNotification(_, _):
                return .doNothing
            case .unscheduleNotification(_):
                return .doNothing
            }
        }
    }
}
