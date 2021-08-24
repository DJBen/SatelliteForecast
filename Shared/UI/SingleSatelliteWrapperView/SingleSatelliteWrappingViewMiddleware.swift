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
        EffectMiddleware<SingleSatelliteWrappingViewAction, AppAction, AppState, Void>
            .onAction { action, _, getState in
                switch action {
                case let .loadSingleSatellite(params):
                    func calculatePass(infoMap: Map<Int, SatelliteInfo>) -> AppAction? {
                        guard let satelliteInfo = infoMap[params.selectedNoradIndex] else {
                            return nil
                        }
                        guard let observer = params.observer else {
                            return nil
                        }
                        return .allPassesView(
                            .calculatePasses(
                                .init(
                                    selectedNoradIndex: params.selectedNoradIndex,
                                    satelliteInfo: satelliteInfo,
                                    julianDateRange: params.julianDateRange,
                                    observer: observer
                                )
                            )
                        )
                    }
                    
                    return .just(
                        .satelliteLoader(
                            .loadSatelliteCategory(
                                .brightest100,
                                onCompletion: calculatePass(infoMap:)
                            )
                        )
                    )
            }
        }
    }
}
