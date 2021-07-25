//
//  SatelliteOverviewMiddleware.swift
//  SatelliteForcast
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
                var actions: [AppAction] = [
                    .coreLocation(.requestAuthorization),
                    .timer(.start)
                ]

                switch action {
                case let .selectSpecialSatellite(noradIndex):
                    if let _ = noradIndex {
                        actions.append(.singleSatelliteWrappingView(.loadSatelliteList))
                        return .sequence(actions)
                    } else {
                        return .doNothing
                    }
                case let .selectCategory(category):
                    if let category = category {
                        actions.append(.satelliteLoader(.loadSatelliteCategory(category)))
                    }

                    return .sequence(actions)
                }
            }
    }
}
