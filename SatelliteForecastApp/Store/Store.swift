//
//  Store.swift
//  SatelliteForecast
//
//  Created by Ben Lu on 6/4/21.
//

import SatelliteKit
import SatelliteForecast
import SatelliteForecastImpl
import SwiftRex
import CombineRex

class Store: ReduxStoreBase<AppAction, AppState> {
    static let shared = Store()

    static let reducer: Reducer<AppAction, AppState> = [
        Reducer.locationReducer.lift(),
        Reducer.locationOutputReducer.lift(),
        Reducer<NotificationAction, AppState>.notificationReducer.lift(action: \.notification),
        Reducer.elementsLoaderReducer.lift(),
        Reducer.elementsLoaderOutputReducer.lift(),
        Reducer.satelliteOverviewReducer.lift(),
        Reducer.settingsOverviewReducer.lift(),
        Reducer.satelliteListViewReducer.lift(),
        Reducer.allPassesViewReducer.lift(),
        Reducer<SatelliteElevationGraphAction, SatelliteElevationGraphResources>.satelliteElevationGraphReducer
        .lift(
            action: \.satelliteElevationGraph,
            state: \.satelliteElevationGraphResources
        ),
        Reducer.passViewReducer.lift(),
        Reducer.skyChartOutputReducer.lift(),
        Reducer.elementsPropagatorReducer.lift(),
        Reducer.elementsPropagatorOutputReducer.lift(),
        Reducer<DebugMenuAction, DebugMenuState>.debugMenuReducer.lift(),
        Reducer.backgroundSkyReducer.lift(),
        Reducer.realtimeSkyReducer.lift(),
        Reducer.realtimeSkyOutputReducer.lift(),
        Reducer.rootViewReducer.lift(),
        Reducer.passAlarmSettingsModalReducer.lift(),
        Reducer.detailedPassViewReducer.lift()
    ]
    .reduce(Reducer<AppAction, AppState>.identity, <>)

    static func buildMiddleware(
        elementsLoader: ElementsLoader
    ) -> AnyMiddleware<AppAction, AppAction, AppState> {
        let middlewares: [AnyMiddleware<AppAction, AppAction, AppState>] = [
            LocationMiddleware().lift(),
            EffectMiddleware.appDelegate
            .lift(
                inputAction: \.appDelegate
            )
            .eraseToAnyMiddleware(),
            EffectMiddleware.backgroundTask.lift(),
            EffectMiddleware.notification
            .lift(
                inputAction: \.notification
            )
            .inject(
                NotificationMiddlewareDependencies(dateProvider: Date.init)
            )
            .eraseToAnyMiddleware(),
            EffectMiddleware.locationChainer.lift(),
            EffectMiddleware.locationToElementsPropagator.lift(),
            EffectMiddleware.locationToRealtimeSky.lift(),
            EffectMiddleware.locationOutputLogger.lift(),
            EffectMiddleware.elementsLoader.lift(
                dependencies: ElementsLoaderDependencies(
                    elementsLoader: elementsLoader,
                    dateProvider: Date.init
                )
            ),
            EffectMiddleware.elementsPropagator.lift(),
            EffectMiddleware.elementsPropagatorChainer.lift(),
            EffectMiddleware.elementsLoaderToElementsPropagator.lift(),
            EffectMiddleware.elementsLoaderToSatelliteList.lift(),
            EffectMiddleware.selectSpecialSatelliteAfterElementsLoader.lift(),
            EffectMiddleware.rootViewElementsLoader.lift(),
            EffectMiddleware.satelliteOverviewToElementLoader.lift(),
            EffectMiddleware.satelliteListViewToElementPropagator.lift(),
            EffectMiddleware.satelliteListToElementLoader.lift(),
            EffectMiddleware.singleSatelliteWrappingViewToElementsLoader.lift(),
            EffectMiddleware.allPassesViewToElementsPropagator.lift(),
            EffectMiddleware.allPassesViewToNotification.lift(),
            EffectMiddleware.skyChart.lift(),
            EffectMiddleware.satelliteElevationGraph.lift(),
            EffectMiddleware.alarmSettingsViewToNotification.lift(),
            EffectMiddleware.debugMenu.lift(
                dependencies: DebugMenuMiddlewareDependencies(dateProvider: Date.init)
            ),
            EffectMiddleware.loggerMiddleware.eraseToAnyMiddleware(),
            EffectMiddleware.backgroundSky.lift(),
            EffectMiddleware.realtimeSky.lift(),
            EffectMiddleware.realtimeSkyToElementsLoader.lift(),
            EffectMiddleware.passAlarmSettingsToNotification.lift(),
        ]

        return middlewares.reduce(
            ComposedMiddleware<AppAction, AppAction, AppState>.identity,
            <>
        )
        .eraseToAnyMiddleware()
    }

    private init() {
        let elementsLoader: ElementsLoader
        if ProcessInfo.processInfo.environment["USE_LOCAL_TLES"] == "YES" {
            print("[Elements Loader] Using local Elements loader")
            #if DEBUG
            elementsLoader = LocalElementsLoader()
            #else
            elementsLoader = ElementsLoaderImpl(session: URLSession.shared)
            #endif
        } else {
            elementsLoader = ElementsLoaderImpl(session: URLSession.shared)
        }

        super.init(
            subject: .combine(initialValue: .empty),
            reducer: Store.reducer,
            middleware: Store.buildMiddleware(elementsLoader: elementsLoader),
            emitsValue: .whenDifferent
        )
    }
}
