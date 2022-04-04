//
//  AllPassesViewMiddleware+ElementsPropagator.swift
//  SatelliteForecastApp
//
//  Created by Ben Lu on 4/4/22.
//

import CombineRex
import SatelliteForecast
import SatelliteForecastImpl

extension EffectMiddleware where InputActionType == AllPassesViewAction, OutputActionType == ElementsPropagatorAction, StateType == Void, Dependencies == Void {
    static var allPassesViewToElementsPropagator: EffectMiddleware<AllPassesViewAction, ElementsPropagatorAction, Void, Void> {
        EffectMiddleware<AllPassesViewAction, ElementsPropagatorAction, Void, Void>.onAction { (action, _, getState) -> Effect<Void, ElementsPropagatorAction> in
            switch action {
            case .calculatePasses(let calculatePassesParams):
                return .just(.calculatePasses(calculatePassesParams))
            case .recalculatePasses(let calculatePassesParams):
                return .just(.recalculatePasses(calculatePassesParams))
            case .selectPass(_):
                return .doNothing
            case .scheduleNotification(_, _):
                return .doNothing
            case .unscheduleNotification(_):
                return .doNothing
            }
        }
    }
}

extension EffectMiddleware where InputActionType == AllPassesViewAction, OutputActionType == ElementsPropagatorAction, StateType == Void, Dependencies == Void {
    func lift() -> AnyMiddleware<AppAction, AppAction, AppState> {
        lift(
            inputAction: \.allPassesView,
            outputAction: AppAction.elementsPropagator,
            state: { _ in () }
        )
        .eraseToAnyMiddleware()
    }
}
