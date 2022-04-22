//
//  AllPassesViewMiddleware+Notifications.swift
//  SatelliteForecastApp
//
//  Created by Ben Lu on 4/4/22.
//

import Combine
import CombineRex
import os
import StarryNight
import SatelliteForecast
import SatelliteForecastImpl

fileprivate let logger = Logger(subsystem: "io.djben.allPassesView", category: "middleware")

extension EffectMiddleware where InputActionType == AllPassesViewAction, OutputActionType == NotificationAction, StateType == Void, Dependencies == Void {
    static var allPassesViewToNotification: EffectMiddleware<AllPassesViewAction, NotificationAction, Void, Void> {
        EffectMiddleware<AllPassesViewAction, NotificationAction, Void, Void>.onAction { (action, _, getState) -> Effect<Void, NotificationAction> in
            switch action {
            case .calculatePasses(_):
                return .doNothing
            case .recalculatePasses(_):
                return .doNothing
            case .selectPass(_):
                return .doNothing
            case .scheduleNotification(let passNotification, let passSnapshots):
                return .just(.generatePreviewAndScheduleNotification(passNotification, passSnapshots: passSnapshots))
            case .unscheduleNotification(let pass):
                return .just(.removePreviewAndUnscheduleNotification(pass))
            }
        }
    }
}

extension EffectMiddleware where InputActionType == AllPassesViewAction, OutputActionType == NotificationAction, StateType == Void, Dependencies == Void {
    func lift() -> AnyMiddleware<AppAction, AppAction, AppState> {
        lift(
            inputAction: \.allPassesView,
            outputAction: AppAction.notification,
            state: { _ in }
        )
        .eraseToAnyMiddleware()
    }
}
