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
                case .loadSatelliteList:
                    if let observer = getState().coreLocationState.location.map(LatLonAlt.init) {
                        let julianDate = getState().julianDate
                        return .sequence([
                            .freezeObservingParams(
                                observer: observer,
                                julianDateRange: JulianDateUtil.createJulianDateRange(now: julianDate)
                            ),
                            .satelliteLoader(.loadSatelliteCategory(.brightest100, shouldCalculatePasses: true)),
                        ])
                    } else {
                        return .doNothing
                    }
                }
            }
    }
}
