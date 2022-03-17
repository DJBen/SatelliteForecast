//
//  RootViewMiddleware.swift
//  SatelliteForecast
//
//  Created by Ben Lu on 3/7/22.
//

import Combine
import CombineRex

extension EffectMiddleware where InputActionType == RootViewAction, OutputActionType == ElementsLoaderAction, StateType == RootViewState, Dependencies == Void {
    static var rootViewElementsLoader: EffectMiddleware<RootViewAction, ElementsLoaderAction, RootViewState, Void> {
        EffectMiddleware.onAction { action, dispatcher, getState in
            switch action {
            case .selectTab(_):
                return .doNothing
            case .loadElementsForRealtimeSky:
                return .sequence(
                    .loadElements(
                        category: .active
                    ),
                    from: dispatcher
                )
            }
        }
    }
}
