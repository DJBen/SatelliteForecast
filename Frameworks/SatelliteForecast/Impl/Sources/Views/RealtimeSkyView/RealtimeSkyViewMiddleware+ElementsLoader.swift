//
//  RealtimeSkyViewMiddleware+ElementsLoader.swift
//  SatelliteForecastImplWiring
//
//  Created by Ben Lu on 4/9/22.
//

@preconcurrency import CombineRex
import SatelliteForecast

extension EffectMiddleware where InputActionType == RealtimeSkyViewAction, OutputActionType == ElementsLoaderAction, StateType == Void, Dependencies == Void {
    public static var realtimeSkyToElementsLoader: EffectMiddleware<RealtimeSkyViewAction, ElementsLoaderAction, Void, Void> {
        EffectMiddleware.onAction { action, dispatcher, getState in
            switch action {
            case .propagateCurrentEphemerides(_, _, _):
                return .doNothing
            case .setRealtimeSkyViewActive(_):
                return .doNothing
            case .loadElements:
                return .just(
                    .loadElements(
                        category: .active,
                        fetchStrategy: .localWithin(21600 /* 6 hours */)
                    )
                )
            case .purgeElements:
                return .doNothing
            }
        }
    }
}
