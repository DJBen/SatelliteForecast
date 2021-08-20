//
//  SatelliteOverviewMiddleware.swift
//  SatelliteForecast
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
                case .selectSpecialSatellite(_):
                    return .just(.singleSatelliteWrappingView(.loadSatelliteList))
                case let .selectCategory(category):
                    return .just(.satelliteLoader(.loadSatelliteCategory(category)))
                case .selectObserver:
                    return .doNothing
                case .selectAlert:
                    return .just(.navigation(.showAlertSettings))
                case .returnToSatelliteOverview:
                    return .doNothing
                }
            }
    }
}
