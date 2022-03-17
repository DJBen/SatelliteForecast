//
//  RootViewMiddleware.swift
//  SatelliteForecast
//
//  Created by Ben Lu on 3/7/22.
//

import Combine
import CombineRex

extension EffectMiddleware where InputActionType == RootViewAction, OutputActionType == TLELoaderAction, StateType == RootViewState, Dependencies == Void {
    static var rootViewTLELoader: EffectMiddleware<RootViewAction, TLELoaderAction, RootViewState, Void> {
        EffectMiddleware.onAction { action, dispatcher, getState in
            switch action {
            case .selectTab(_):
                return .doNothing
            case .loadTLEsForRealtimeSky:
                return .sequence(
                    .loadSatelliteTLEs(
                        category: .active
                    ),
                    from: dispatcher
                )
            }
        }
    }
}
