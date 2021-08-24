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

fileprivate let logger = Logger(subsystem: "io.djben.alarmSettingsView", category: "middleware")

extension EffectMiddleware where InputActionType == AlarmSettingsViewAction, OutputActionType == AppAction, StateType == AppState, Dependencies == Void {
    static var alarmSettingsView: EffectMiddleware<AlarmSettingsViewAction, AppAction, AppState, Void> {
        EffectMiddleware<AlarmSettingsViewAction, AppAction, AppState, Void>.onAction { action, _, getState in
            switch action {
            case .deleteNotifications(let ids):
                return .just(.notification(.cancelNotifications(ids: ids)))
            }
        }
    }
}
