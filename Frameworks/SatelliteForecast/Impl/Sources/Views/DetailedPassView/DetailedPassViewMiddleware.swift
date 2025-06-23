//
//  DetailedPassViewMiddleware.swift
//  SatelliteForecastImpl
//
//  Created by Ben Lu on 5/14/22.
//

import Combine
@preconcurrency import CombineRex

extension EffectMiddleware where InputActionType == DetailedPassViewAction, OutputActionType == DetailedPassViewAction, StateType == DetailedPassViewState, Dependencies == Void {
    static var passView: EffectMiddleware<DetailedPassViewAction, DetailedPassViewAction, DetailedPassViewState, Void> {
        EffectMiddleware.onAction { action, _, getState in
            switch action {
            case .dismissModal:
                return .doNothing
            }
        }
    }
}
