//
//  AllPassesView+ElementsLoader.swift
//  SatelliteForecastApp
//
//  Created by Ben Lu on 4/1/22.
//

import CombineRex
import CombineRextensions
import SatelliteForecastImpl

extension EffectMiddleware where InputActionType == ElementsLoaderOutput, OutputActionType == AllPassesViewAction, StateType == ElementsLoaderState, Dependencies == Void {
    /// This middleware triggers `calculatePass` event after satellite has been loaded
    static var calculatePassAfterElementsLoader: EffectMiddleware<ElementsLoaderOutput, AllPassesViewAction, ElementsLoaderState, Void> {
        EffectMiddleware.onAction { action, dispatcher, getState in
            switch action {
            case .loadedSatelliteElements(_, let satelliteInfoMap, _, _, let calculatePass):
                guard let calculatePass = calculatePass, let satelliteInfo = satelliteInfoMap[calculatePass.noradIndex] else {
                    return .doNothing
                }

                return .just(
                    .calculatePasses(
                        AllPassesViewAction.CalculatePassesParams(
                            selectedNoradIndex: calculatePass.noradIndex,
                            satelliteInfo: satelliteInfo,
                            julianDateRange: calculatePass.dateRange,
                            observer: calculatePass.observer
                        )
                    ),
                    from: dispatcher
                )

            case .failedLoadingElements(_, _):
                return .doNothing
            }
        }
    }
}
