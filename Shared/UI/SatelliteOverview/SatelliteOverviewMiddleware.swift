//
//  SatelliteOverviewMiddleware.swift
//  SatelliteForcast (iOS)
//
//  Created by Ben Lu on 6/30/21.
//

import Foundation
import Combine
import CombineRex
import SatelliteKit


extension EffectMiddleware where
    InputActionType == SatelliteOverviewViewAction,
    OutputActionType == AppAction,
    StateType == AppState,
    Dependencies == Void {

    static var satelliteOverview: EffectMiddleware<SatelliteOverviewViewAction, AppAction, AppState, Void> {
        EffectMiddleware<SatelliteOverviewViewAction, AppAction, AppState, Void>
            .onAction { action, _, state in
                switch action {
                case .selectSpecialSatellite(noradIndex: _):
                    return .just(.satelliteLoaderInput(.loadSatelliteCategory(.brightest100)))
                case .selectCategory(_):
                    return .doNothing
                }
            }
    }
}
