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

struct SatelliteListViewMiddlewareDependencies {
    let elementsLoader: ElementsLoader
}

extension EffectMiddleware where InputActionType == SatelliteListViewAction, OutputActionType == AppAction, StateType == AppState, Dependencies == SatelliteListViewMiddlewareDependencies {

    /// A middeware that listens to `SatelliteListViewAction`.
    /// - `selectSatellite(noradIndex)`: It asynchronously does two things:
    ///   - Generate a coarse ephemeris of the satellite over a long future period.
    ///   - Find all the passes in the same period, and generate a fine ephemeris during each pass.
    ///
    ///   Thus this effect will have two action outputs before it completes.
    static var satelliteListView: MiddlewareReader<SatelliteListViewMiddlewareDependencies, EffectMiddleware<SatelliteListViewAction, AppAction, AppState, SatelliteListViewMiddlewareDependencies>> {
        EffectMiddleware.onAction { (action, dispatcher, getState) -> Effect<SatelliteListViewMiddlewareDependencies, AppAction> in
            switch action {
            case let .selectSatellite(params):
                guard let params = params else {
                    return .doNothing
                }

                guard let observer = params.observer else {
                    return .doNothing
                }

                return .sequence([
                    .allPassesView(
                        .calculatePasses(
                            .init(
                                selectedNoradIndex: params.noradIndex,
                                satelliteInfo: params.satelliteInfo,
                                julianDateRange: params.julianDateRange,
                                observer: observer
                            )
                        )
                    ),
                ])

            case .satelliteSearchTextChanged(_):
                return .doNothing

            case .retryLoadingSatelliteList:
                guard let category = getState().navigationState.listNavigation.category else {
                    return .doNothing
                }

                return Effect(token: "retryLoadingSatelliteList") { context -> AnyPublisher<DispatchedAction<AppAction>, Never> in
                    context.dependencies.elementsLoader.loadElementsPublisher(
                        category: category
                    )
                    .map {
                        DispatchedAction(
                            AppAction.elementsLoaderOutput(
                                .loadedSatelliteElements(category: category, satelliteInfo: $0)
                            ),
                            dispatcher: dispatcher
                        )
                    }
                    .catch { error in
                        Just(
                            DispatchedAction(
                                AppAction.elementsLoaderOutput(
                                    .failedLoadingElements(category: category, error: error)
                                ),
                                dispatcher: dispatcher
                            )
                        )
                    }
                    .eraseToAnyPublisher()
                }
            }
        }
    }
}
