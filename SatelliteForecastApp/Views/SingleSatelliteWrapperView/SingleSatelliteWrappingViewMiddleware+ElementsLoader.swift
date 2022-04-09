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
import SatelliteForecast
import SatelliteForecastImpl
import SatelliteKit

extension EffectMiddleware where InputActionType == SingleSatelliteWrappingViewAction, OutputActionType == ElementsLoaderAction, StateType == Void, Dependencies == Void {

    static var singleSatelliteWrappingViewToElementsLoader: EffectMiddleware<SingleSatelliteWrappingViewAction, ElementsLoaderAction, Void, Void> {
        EffectMiddleware<SingleSatelliteWrappingViewAction, ElementsLoaderAction, Void, Void>.onAction { action, _, getState in
            switch action {
                case let .loadSingleSatellite(params):
                return .just(
                    .loadElements(
                        category: .brightest100,
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

    func lift() -> AnyMiddleware<AppAction, AppAction, AppState> {
        lift(
            inputAction: \.singleSatelliteWrappingView,
            outputAction: AppAction.elementsLoader,
            state: { _ in }
        )
        .eraseToAnyMiddleware()
    }
}
