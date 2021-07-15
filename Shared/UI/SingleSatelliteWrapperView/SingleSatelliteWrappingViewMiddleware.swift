//
//  SingleSatelliteWrappingViewMiddleware.swift
//  SatelliteForcast
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
            .onAction { action, _, getState in
                switch action {
                case .loadSatelliteList:
                    if let observer = getState().coreLocationState.location.map(LatLonAlt.init) {
                        let julianDate = getState().satelliteLoaderState.referenceDate
                        return .sequence([
                            .freezeObservingParams(
                                observer: observer,
                                julianDateRange: julianDate.advanced(by: -TimeConstants.hrs2day * 2)..<julianDate.advanced(by: TimeConstants.hrs2day * 22)
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
