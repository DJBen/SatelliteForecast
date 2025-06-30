//
//  SatelliteOverviewView+ElementsLoader.swift
//  SatelliteForecast
//
//  Created by Ben Lu on 4/1/22.
//

@preconcurrency import CombineRex
@preconcurrency import CombineRextensions
import SatelliteForecast

extension EffectMiddleware where InputActionType == ElementsLoaderOutput, OutputActionType == SatelliteOverviewViewAction, StateType == ElementsLoaderState, Dependencies == Void {
    /// This middleware triggers `calculatePass` event after satellite has been loaded
    public static var selectSpecialSatelliteAfterElementsLoader: EffectMiddleware<ElementsLoaderOutput, SatelliteOverviewViewAction, ElementsLoaderState, Void> {
        EffectMiddleware.onAction { action, dispatcher, getState in
            switch action {
            case .loadedSatelliteElements(_, _, let selectNoradIndex, _):
                guard let selectNoradIndex = selectNoradIndex, let category = SatelliteCategory(noradIndex: selectNoradIndex.noradIndex), let specialSatellite = SpecialSatellite(category) else {
                    return .doNothing
                }

                return .just(
                    .selectSatellite(
                        specialSatellite: specialSatellite,
                        julianDateRange: selectNoradIndex.dateRange,
                        observer: selectNoradIndex.observer
                    ),
                    from: dispatcher
                )

            case .failedLoadingElements(_, _):
                return .doNothing
            }
        }
    }
}
