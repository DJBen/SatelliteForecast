//
//  SatelliteListViewMiddleware.swift
//  SatelliteForecast
//
//  Created by Ben Lu on 6/5/21.
//

import Foundation
import os
import Combine
import CombineRex
import SatelliteForecastCore
import SatelliteKit

fileprivate let logger = Logger(subsystem: "io.djben.satelliteListView", category: "middleware")

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
                    guard let noradIndex = noradIndex else {
                        return .doNothing
                    }
                    guard let observer = getState().observer else {
                        logger.info("Will not select satellite \(noradIndex): lack of observer")
                        return .doNothing
                    }
                    
                    return .sequence([
                        .freezeObservingParams(
                            observer: observer,
                            julianDateRange: JulianDateUtil.createJulianDateRange(now: getState().julianDate)
                        ),
                        .allPassesView(.calculatePasses(noradIndex: noradIndex, observer: observer)),
                    ])
                    
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
