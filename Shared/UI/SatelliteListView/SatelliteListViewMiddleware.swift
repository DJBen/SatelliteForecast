//
//  SatelliteListViewMiddleware.swift
//  SatelliteForecast
//
//  Created by Ben Lu on 6/5/21.
//

import Foundation
import Combine
import CombineRex
import SatelliteForecastCore
import SatelliteKit


extension EffectMiddleware where InputActionType == SatelliteListViewAction, OutputActionType == AppAction, StateType == AppState, Dependencies == Void {

    /// A middeware that listens to `SatelliteListViewAction`.
    /// - `selectSatellite(noradIndex)`: It asynchronously does two things:
    ///   - Generate a coarse ephemeris of the satellite over a long future period.
    ///   - Find all the passes in the same period, and generate a fine ephemeris during each pass.
    ///
    ///   Thus this effect will have two action outputs before it completes.
    static func satelliteListView(satelliteLoader: SatelliteLoader) -> EffectMiddleware<SatelliteListViewAction, AppAction, AppState, Void> {
        EffectMiddleware<SatelliteListViewAction, AppAction, AppState, Void>
            .onAction { (action, _, getState) -> Effect<Void, AppAction> in
                switch action {
                case let .selectSatellite(noradIndex):
                    if let observer = getState().coreLocationState.location.map(LatLonAlt.init),
                       let _ = noradIndex {
                        let julianDate = getState().julianDate

                        return .sequence([
                            .freezeObservingParams(
                                observer: observer,
                                julianDateRange: JulianDateUtil.createJulianDateRange(now: julianDate)
                            ),
                            .allPassesView(.calculatePasses)
                        ])
                    } else {
                        return .doNothing
                    }
                case .satelliteSearchTextChanged(_):
                    return .doNothing

                case .retryLoadingSatelliteList:
                    guard let category = getState().navigationState.selectedCategory else {
                        return .doNothing
                    }

                    return satelliteLoader.loadSatelliteCategoryPublisher(category: category)
                        .map(AppAction.satelliteLoader)
                        .asEffect(info: nil)
                }
            }
    }
}
