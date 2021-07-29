//
//  DebugMenuMiddleware.swift
//  SatelliteForecast
//
//  Created by Ben Lu on 7/25/21.
//

import Foundation
import Combine
import CombineRex
import SatelliteKit

extension EffectMiddleware where
    InputActionType == DebugMenuAction,
    OutputActionType == AppAction,
    StateType == AppState,
    Dependencies == Void {

    static var debugMenu: EffectMiddleware<DebugMenuAction, AppAction, AppState, Void> {
        EffectMiddleware<DebugMenuAction, AppAction, AppState, Void>
            .onAction { action, _, getState in
                switch action {
                case .toggleDebugMenu(_):
                    return .doNothing
                case .toggleFreezeTime(_):
                    return .doNothing
                case .toggleMockedOffset(_):
                    return .just(.timer(.tick(Date().julianDate)))
                case .setMockedDateOffset(_):
                    return .just(.timer(.tick(Date().julianDate)))
                }
            }
    }
}
