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
import SatelliteForecastCore

extension EffectMiddleware where
    InputActionType == SatelliteOverviewViewAction,
    OutputActionType == AppAction,
    StateType == AppState,
    Dependencies == Void {

    static var satelliteOverview: EffectMiddleware<SatelliteOverviewViewAction, AppAction, AppState, Void> {
        EffectMiddleware<SatelliteOverviewViewAction, AppAction, AppState, Void>
            .onAction { action, _, getState in
                switch action {          
                case let .selectSpecialSatellite(params):
                    return .sequence([
                        .singleSatelliteWrappingView(
                            .loadSingleSatellite(
                                .init(
                                    selectedNoradIndex: params.noradIndex,
                                    julianDateRange: params.julianDateRange,
                                    observer: params.observer
                                )
                            )
                        )
                    ])
                    
                case let .selectCategory(category):
                    return .sequence([
                        .satelliteLoader(.loadSatelliteCategory(category))
                    ])
                    
                case .selectObserver:
                    return .doNothing
                    
                case .selectAlert:
                    return .doNothing

                case .returnToSatelliteOverview:
                    return .doNothing
                }
            }
    }
}
