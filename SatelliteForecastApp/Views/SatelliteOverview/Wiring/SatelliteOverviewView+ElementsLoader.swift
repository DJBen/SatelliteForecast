//
//  SatelliteOverviewView+ElementsLoader.swift
//  SatelliteForecast
//
//  Created by Ben Lu on 4/1/22.
//

import CombineRex
import CombineRextensions
import SatelliteForecastImpl

extension EffectMiddleware where InputActionType == ElementsLoaderOutput, OutputActionType == SatelliteOverviewViewAction, StateType == ElementsLoaderState, Dependencies == Void {
    /// This middleware triggers `calculatePass` event after satellite has been loaded
    static var selectSpecialSatelliteAfterElementsLoader: EffectMiddleware<ElementsLoaderOutput, SatelliteOverviewViewAction, ElementsLoaderState, Void> {
        EffectMiddleware.onAction { action, dispatcher, getState in
            switch action {
            case .loadedSatelliteElements(_, _, let selectSpecialNoradIndex, _, _):
                guard let selectSpecialNoradIndex = selectSpecialNoradIndex else {
                    return .doNothing
                }

                return .just(
                    .selectSpecialSatellite(
                        SatelliteOverviewViewAction.SelectSpecialSatelliteParams(
                            noradIndex: selectSpecialNoradIndex.noradIndex,
                            julianDateRange: selectSpecialNoradIndex.dateRange,
                            observer: selectSpecialNoradIndex.observer
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
