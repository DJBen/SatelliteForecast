//
//  SingleSatelliteWrappingViewMiddleware.swift
//  SatelliteForecast
//
//  Created by Ben Lu on 7/10/21.
//

import BTree
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
        EffectMiddleware<SingleSatelliteWrappingViewAction, AppAction, AppState, Void>.onAction { action, _, getState in
            switch action {
                case let .loadSingleSatellite(params):
                return .just(
                    .tleLoader(
                        .loadSatelliteTLEs(
                            category: .brightest100,
                            calculatePass: params.observer.map { observer in
                                TLELoaderCalculatePassParam(
                                    noradID: params.selectedNoradIndex,
                                    dateRange: params.julianDateRange,
                                    observer: observer
                                )
                            }
                        )
                    )
                )
            }
        }
    }
}
