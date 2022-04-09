//
//  AlarmSettingsViewMiddleware.swift
//  AlarmSettingsViewMiddleware
//
//  Created by Ben Lu on 8/20/21.
//

import Foundation
import os
import Combine
import CombineRex
import SatelliteForecastImpl

fileprivate let logger = Logger(subsystem: "io.djben.alarmSettingsView", category: "middleware")

extension EffectMiddleware where InputActionType == AlarmSettingsViewAction, OutputActionType == NotificationAction, StateType == Void, Dependencies == Void {
    static var alarmSettingsViewToNotification: EffectMiddleware<AlarmSettingsViewAction, NotificationAction, Void, Void> {
        EffectMiddleware<AlarmSettingsViewAction, NotificationAction, Void, Void>.onAction { action, _, getState in
            switch action {
            case .deleteNotifications(let ids):
                return .just(.cancelNotifications(ids: ids))
            }
        }
    }

    func lift() -> AnyMiddleware<AppAction, AppAction, AppState> {
        lift(
            inputAction: \.alarmSettingsView,
            outputAction: AppAction.notification,
            state: { _ in }
        )
        .eraseToAnyMiddleware()
    }
}
