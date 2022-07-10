//
//  RootViewMiddleware+ElementsLoader.swift
//  SatelliteForecast
//
//  Created by Ben Lu on 3/7/22.
//

import Combine
import CombineRex
import SatelliteForecastImpl

extension EffectMiddleware where InputActionType == RootViewAction, OutputActionType == ElementsLoaderAction, StateType == RootViewState, Dependencies == Void {
    static var rootViewElementsLoader: EffectMiddleware<RootViewAction, ElementsLoaderAction, RootViewState, Void> {
        EffectMiddleware.onAction { action, dispatcher, getState in
            switch action {
            case .selectTab(let tab):
                switch tab {
                case .realtimeSky:
                    return .just(
                        .loadElements(
                            category: .active
                        )
                    )
                case .forecast, .settings:
                    return .doNothing
                }
            }
        }
    }
}
