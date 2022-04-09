//
//  ElementsLoaderMiddleware+SatelliteListView.swift
//  SatelliteForecast
//
//  Created by Ben Lu on 4/1/22.
//

import CombineRex
import CombineRextensions
import SatelliteForecastImpl

extension EffectMiddleware where InputActionType == ElementsLoaderOutput, OutputActionType == SatelliteListViewAction, StateType == Void, Dependencies == Void {
    /// This middleware triggers `calculatePass` event after satellite has been loaded
    static var elementsLoaderToSatelliteList: EffectMiddleware<ElementsLoaderOutput, SatelliteListViewAction, Void, Void> {
        EffectMiddleware.onAction { action, dispatcher, getState in
            switch action {
            case .loadedSatelliteElements(_, let satelliteInfoMap, _, let selectNoradIndex, _):
                guard let selectNoradIndex = selectNoradIndex, let satelliteInfo = satelliteInfoMap[selectNoradIndex.noradIndex] else {
                    return .doNothing
                }

                return .just(
                    .selectSatellite(
                        SatelliteListViewAction.SelectSatelliteParams(
                            noradIndex: selectNoradIndex.noradIndex,
                            satelliteInfo: satelliteInfo,
                            julianDateRange: selectNoradIndex.dateRange,
                            observer: selectNoradIndex.observer
                        )
                    ),
                    from: dispatcher
                )

            case .failedLoadingElements(_, _):
                return .doNothing
            }
        }
    }

    func lift() -> AnyMiddleware<AppAction, AppAction, AppState> {
        lift(
            inputAction: \.elementsLoaderOutput,
            outputAction: AppAction.satelliteListView,
            state: { _ in }
        )
        .eraseToAnyMiddleware()
    }
}
