//
//  RootViewMiddleware+ElementsLoader.swift
//  SatelliteForecast
//
//  Created by Ben Lu on 3/7/22.
//

import Combine
@preconcurrency import CombineRex
import SatelliteForecastImpl

extension EffectMiddleware where InputActionType == RootViewAction, OutputActionType == ElementsLoaderAction, StateType == RootViewState, Dependencies == Void {
    public static var rootViewElementsLoader: EffectMiddleware<RootViewAction, ElementsLoaderAction, RootViewState, Void> {
        EffectMiddleware.onAction { action, dispatcher, getState in
            switch action {
            case .selectTab(let tab):
                switch tab {
                case .realtimeSky:
                    return .just(
                        .loadElements(
                            category: .active,
                            fetchStrategy: .localWithin(21600 /* 6 hours */)
                        )
                    )
                case .forecast, .satellites, .settings:
                    return .doNothing
                }
            }
        }
    }
}
