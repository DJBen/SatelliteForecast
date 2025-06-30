//
//  ElementsLoaderMiddleware+SatelliteListView.swift
//  SatelliteForecast
//
//  Created by Ben Lu on 4/1/22.
//

@preconcurrency import CombineRex
@preconcurrency import CombineRextensions
import SatelliteForecast

extension EffectMiddleware where InputActionType == ElementsLoaderOutput, OutputActionType == SatelliteListViewAction, StateType == Void, Dependencies == Void {
    /// This middleware triggers `calculatePass` event after satellite has been loaded
    public static var elementsLoaderToSatelliteList: EffectMiddleware<ElementsLoaderOutput, SatelliteListViewAction, Void, Void> {
        EffectMiddleware.onAction { action, dispatcher, getState in
            switch action {
            case .loadedSatelliteElements(let category, let satelliteInfoMap, let selectNoradIndex, _):
                guard let selectNoradIndex = selectNoradIndex, let satelliteInfo = satelliteInfoMap[selectNoradIndex.noradIndex], ![25544, 48274].contains(selectNoradIndex.noradIndex) else {
                    return .doNothing
                }

                return .just(
                    .selectSatellite(
                        SatelliteListViewAction.SelectSatelliteParams(
                            noradIndex: selectNoradIndex.noradIndex,
                            satelliteInfo: satelliteInfo,
                            julianDateRange: selectNoradIndex.dateRange,
                            observer: selectNoradIndex.observer
                        ),
                        category: category
                    ),
                    from: dispatcher
                )

            case .failedLoadingElements(_, _):
                return .doNothing
            }
        }
    }
}
