//
//  SingleSatelliteWrappingViewMiddleware.swift
//  SatelliteForcast (iOS)
//
//  Created by Ben Lu on 7/10/21.
//

import Foundation
import Combine
import CombineRex
import SatelliteKit


extension EffectMiddleware where
    InputActionType == SingleSatelliteWrappingViewAction,
    OutputActionType == AppAction,
    StateType == AppState,
    Dependencies == Void {

    static var singleSatelliteWrappingView: EffectMiddleware<SingleSatelliteWrappingViewAction, AppAction, AppState, Void> {
        EffectMiddleware<SingleSatelliteWrappingViewAction, AppAction, AppState, Void>
            .onAction { action, _, state in
                switch action {
                case .loadSatelliteList:
                    return .just(.satelliteLoader(.loadSatelliteCategory(.brightest100)))
                }
            }
    }
}
