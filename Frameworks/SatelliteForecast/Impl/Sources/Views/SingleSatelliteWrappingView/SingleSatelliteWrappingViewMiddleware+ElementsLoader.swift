//
//  SingleSatelliteWrappingViewMiddleware.swift
//  SatelliteForecast
//
//  Created by Ben Lu on 7/10/21.
//

import BTree
import Foundation
import Combine
@preconcurrency import CombineRex
import SatelliteForecast
@preconcurrency import SatelliteKit

extension EffectMiddleware where InputActionType == SingleSatelliteWrappingViewAction, OutputActionType == ElementsLoaderAction, StateType == Void, Dependencies == Void {

    public static var singleSatelliteWrappingViewToElementsLoader: EffectMiddleware<SingleSatelliteWrappingViewAction, ElementsLoaderAction, Void, Void> {
        EffectMiddleware<SingleSatelliteWrappingViewAction, ElementsLoaderAction, Void, Void>.onAction { action, _, getState in
            switch action {
                case let .loadSingleSatellite(params):
                let category: SatelliteCategory = if params.selectedNoradIndex == 25544 {
                    .iss
                } else {
                    .tianhe
                }
                return .just(
                    .loadElements(
                        category: category,
                        fetchStrategy: .localWithin(21600 /* 6 hours */),
                        calculatePass: params.observer.map { observer in
                            ElementsLoaderCalculatePassParam(
                                noradIndex: params.selectedNoradIndex,
                                dateRange: params.julianDateRange,
                                observer: observer
                            )
                        }
                    )
                )
            }
        }
    }
}
