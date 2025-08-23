//
//  DebugMenuReducer.swift
//  SatelliteForecast
//
//  Created by Ben Lu on 7/25/21.
//

import Foundation
@preconcurrency import SwiftRex
import SatelliteForecast

extension Reducer where ActionType == DebugMenuAction, StateType == DebugMenuState {
    public static let debugMenuReducer = Reducer.reduce { action, state in
        switch action {
        case let .toggleDebugMenu(isVisible):
            state.config.isDebugMenuVisible = isVisible
        case let .toggleFreezeTime(isOn):
            if isOn {
                state.config.frozenAt = state.trueJulianDate + (state.config.mockedOffsetOn ? state.config.mockedOffset : 0)
            } else {
                state.config.frozenAt = nil
            }
        case let .toggleMockedOffset(isOn):
            state.config.mockedOffsetOn = isOn
            if isOn && state.config.frozenAt != nil {
                state.config.frozenAt = state.trueJulianDate + (state.config.mockedOffsetOn ? state.config.mockedOffset : 0)
            }
        case let .setMockedDateOffset(offset):
            state.config.mockedOffset = offset
            if state.config.frozenAt != nil {
                state.config.frozenAt = state.trueJulianDate + (state.config.mockedOffsetOn ? state.config.mockedOffset : 0)
            }
            
        case let .toggleRapidNotificationDelivery(isOn):
            state.config.rapidNotificationDelivery = isOn
            
        case .fetchNotifications:
            break
            
        case .triggerPassDeepLink(category: _, noradIndex: _):
            state.config.isDebugMenuVisible = false
            
        case .resetOnboarding:
            break // This will be handled by middleware
        case .resetMainOnboarding:
            break // This will be handled by middleware
        case .resetAllPassesOnboarding:
            break // This will be handled by middleware
        case .resetSkyChartTutorial:
            break // This will be handled by middleware
        }
    }
}
