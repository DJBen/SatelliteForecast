//
//  PassViewMiddleware.swift
//  SatelliteForecastImpl
//
//  Created by Ben Lu on 5/13/22.
//

import Combine
@preconcurrency import CombineRex
import SatelliteForecast

extension EffectMiddleware where InputActionType == PassViewAction, OutputActionType == PassViewAction, StateType == PassViewState, Dependencies == Void {
    public static var passView: EffectMiddleware<PassViewAction, PassViewAction, PassViewState, Void> {
        EffectMiddleware.onAction { action, _, getState in
            switch action {
            case .showDetailPassView:
                return .doNothing
            case .showAlarmConfiguration(_):
                return .doNothing
            case .unscheduleAlarm(_):
                return .doNothing
            }
        }
    }
}

extension EffectMiddleware where InputActionType == PassViewAction, OutputActionType == NotificationAction, StateType == PassViewState, Dependencies == Void {
    public static var passViewToNotification: EffectMiddleware<PassViewAction, NotificationAction, PassViewState, Void> {
        EffectMiddleware.onAction { action, _, getState in
            switch action {
            case .showDetailPassView:
                return .doNothing
            case .showAlarmConfiguration(_):
                return .doNothing
            case .unscheduleAlarm(let pass):
                return .just(.removePreviewAndUnscheduleNotification(pass))
            }
        }
    }
}
