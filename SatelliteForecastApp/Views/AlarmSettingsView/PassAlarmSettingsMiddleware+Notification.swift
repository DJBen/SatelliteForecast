//
//  PassAlarmSettingsMiddleware+Notification.swift
//  SatelliteForecastApp
//
//  Created by Ben Lu on 4/22/22.
//

import CombineRex
import SatelliteForecastImpl

extension EffectMiddleware where InputActionType == PassAlarmSettingsModalViewAction, OutputActionType == NotificationAction, StateType == Void, Dependencies == Void {
    static var passAlarmSettingsToNotification: EffectMiddleware<PassAlarmSettingsModalViewAction, NotificationAction, Void, Void> {
        EffectMiddleware.onAction { action, dispatcher, getState in
            switch action {
            case .dismissModal:
                return .doNothing
            case .scheduleAlarm(let passNotification, let passSnapshots):
                return .just(
                    .generatePreviewAndScheduleNotification(passNotification, passSnapshots: passSnapshots)
                )
            case .unscheduleAlarm(let pass):
                return .just(
                    .removePreviewAndUnscheduleNotification(pass)
                )
            }
        }
    }

    func lift() -> AnyMiddleware<AppAction, AppAction, AppState> {
        lift(
            inputAction: \.passAlarmSettings,
            outputAction: AppAction.notification,
            state: { _ in }
        )
        .eraseToAnyMiddleware()
    }
}
