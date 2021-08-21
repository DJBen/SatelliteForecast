//
//  DebugMenuReducer.swift
//  SatelliteForecast
//
//  Created by Ben Lu on 7/25/21.
//

import Foundation
import SwiftRex

extension Reducer where ActionType == DebugMenuAction, StateType == AppState {
    static let debugMenuReducer = Reducer.reduce { action, state in
        switch action {
        case let .toggleDebugMenu(isVisible):
            state.debugMenu.isDebugMenuVisible = isVisible
        case let .toggleFreezeTime(isOn):
            if isOn {
                state.debugMenu.frozenAt = state.satelliteLoaderState.currentDate + (state.debugMenu.mockedOffsetOn ? state.debugMenu.mockedOffset : 0)
            } else {
                state.debugMenu.frozenAt = nil
            }
        case let .toggleMockedOffset(isOn):
            state.debugMenu.mockedOffsetOn = isOn
            if isOn && state.debugMenu.frozenAt != nil {
                state.debugMenu.frozenAt = state.satelliteLoaderState.currentDate + (state.debugMenu.mockedOffsetOn ? state.debugMenu.mockedOffset : 0)
            }
        case let .setMockedDateOffset(offset):
            state.debugMenu.mockedOffset = offset
            if state.debugMenu.frozenAt != nil {
                state.debugMenu.frozenAt = state.satelliteLoaderState.currentDate + (state.debugMenu.mockedOffsetOn ? state.debugMenu.mockedOffset : 0)
            }
            
        case let .toggleRapidNotificationDelivery(isOn):
            state.debugMenu.rapidNotificationDelivery = isOn
            
        case .fetchNotifications:
            break
        }
    }
}
