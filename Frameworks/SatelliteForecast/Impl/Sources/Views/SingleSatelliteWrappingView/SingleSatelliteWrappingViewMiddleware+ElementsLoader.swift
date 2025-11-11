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
            func elementsCategory(for noradIndex: UInt) -> SatelliteCategory {
                if noradIndex == 25544 {
                    return .iss
                } else {
                    return .tianhe
                }
            }

            func calculatePassParam(_ params: SingleSatelliteWrappingViewAction.LoadSingleSatelliteParams) -> ElementsLoaderCalculatePassParam? {
                params.observer.map { observer in
                    ElementsLoaderCalculatePassParam(
                        noradIndex: params.selectedNoradIndex,
                        dateRange: params.julianDateRange,
                        observer: observer
                    )
                }
            }

            switch action {
            case let .loadSingleSatellite(params):
                return .just(
                    .loadElements(
                        category: elementsCategory(for: params.selectedNoradIndex),
                        fetchStrategy: .localWithin(21600 /* 6 hours */),
                        calculatePass: calculatePassParam(params)
                    )
                )

            case let .reloadSingleSatellite(params):
                let category = elementsCategory(for: params.selectedNoradIndex)
                category.removeCachedElements()
                return .just(
                    .loadElements(
                        category: category,
                        fetchStrategy: .onlineFirst,
                        calculatePass: calculatePassParam(params)
                    )
                )
            }
        }
    }
}
