//
//  SingleSatelliteWrappingViewMiddleware.swift
//  SatelliteForecast
//
//  Created by Ben Lu on 7/10/21.
//

import Foundation
import Combine
import CombineRex
import SatelliteForecastCore
import SatelliteKit


extension EffectMiddleware where
    InputActionType == SingleSatelliteWrappingViewAction,
    OutputActionType == AppAction,
    StateType == AppState,
    Dependencies == Void {

    static var singleSatelliteWrappingView: EffectMiddleware<SingleSatelliteWrappingViewAction, AppAction, AppState, Void> {
        EffectMiddleware<SingleSatelliteWrappingViewAction, AppAction, AppState, Void>
            .onAction { action, _, getState in
                switch action {
                case .loadSingleSatellite:
                    return .just(
                        .satelliteLoader(
                            .loadSatelliteCategory(.brightest100)
                        )
                    )
                case let .calculateSingleSatellitePass(noradIndex):
                    guard let observer = getState().observer else {
                        return .doNothing
                    }
                    
                    return .just(
                        .allPassesView(.calculatePasses(noradIndex: noradIndex, observer: observer))
                    )
                }
            }
    }
}
