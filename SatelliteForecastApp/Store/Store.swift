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
        Reducer.navigationReducerFromLocationAction.lift(),
        Reducer<NotificationAction, AppState>.notificationReducer.lift(action: \.notification),
        Reducer<ElementsLoaderAction, ElementsLoaderState>.elementsLoaderReducer.lift(),
        Reducer<ElementsLoaderOutput, ElementsLoaderState>.elementsLoaderOutputReducer.lift(),
        Reducer.satelliteOverviewReducer.lift(),
        Reducer.settingsOverviewReducer.lift(),
        Reducer<SatelliteListViewAction, AppState>.satelliteListViewReducer.lift(action: \.satelliteListView),
        Reducer.allPassesViewReducer.lift(),
        Reducer<SatelliteElevationGraphAction, SatelliteElevationGraphResources>.satelliteElevationGraphReducer
        .lift(
            action: \.satelliteElevationGraph,
            state: \.satelliteElevationGraphResources
        ),
        Reducer.skyChartOutputReducer.lift(),
        Reducer.elementsPropagatorReducer.lift(),
        Reducer.elementsPropagatorOutputReducer.lift(),
        Reducer<TimerAction, AppState>.timerReducer.lift(action: \.timer),
        Reducer<DebugMenuAction, DebugMenuState>.debugMenuReducer.lift(),
        Reducer.backgroundSkyReducer.lift(),
        Reducer.realtimeSkyReducer.lift(),
        Reducer.realtimeSkyOutputReducer.lift(),
        Reducer.rootViewReducer.lift()
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
                .eraseToAnyMiddleware(),
            EffectMiddleware.locationChainer.lift(),
            EffectMiddleware.locationToElementsPropagator.lift(),
            EffectMiddleware.locationOutputLogger.lift(),
            EffectMiddleware.elementsLoader
                .lift()
                .inject(
                    ElementsLoaderDependencies(elementsLoader: elementsLoader)
                )
                .eraseToAnyMiddleware(),
            EffectMiddleware.elementsPropagator.lift(),
            EffectMiddleware.elementsPropagatorChainer.lift(),
            EffectMiddleware.elementsLoaderToElementsPropagator.lift(),
            EffectMiddleware.selectSatelliteAfterElementsLoader.lift(),
            EffectMiddleware.selectSpecialSatelliteAfterElementsLoader.lift(),
            EffectMiddleware.rootViewElementsLoader.lift(),
            EffectMiddleware.satelliteOverview.lift(),
            EffectMiddleware.satelliteListView
                .lift(
                    inputAction: \.satelliteListView
                )
                .inject(
                    SatelliteListViewMiddlewareDependencies(elementsLoader: elementsLoader)
                )
                .eraseToAnyMiddleware(),
            EffectMiddleware.singleSatelliteWrappingView
                .lift(
                    inputAction: \.singleSatelliteWrappingView
                )
                .eraseToAnyMiddleware(),
            EffectMiddleware.allPassesViewToElementsPropagator.lift(),
            EffectMiddleware.allPassesViewToNotification.lift(),
            EffectMiddleware.skyChart.lift(),
            EffectMiddleware.satelliteElevationGraph.lift(),
            EffectMiddleware.timer
                .lift(
                    inputAction: \.timer,
                    outputAction: AppAction.timer
                )
                .eraseToAnyMiddleware(),
            EffectMiddleware.alarmSettingsView
                .lift(
                    inputAction: \.alarmSettingsView
                )
                .eraseToAnyMiddleware(),
            EffectMiddleware.debugMenu.lift(),
            EffectMiddleware.loggerMiddleware.eraseToAnyMiddleware(),
            EffectMiddleware.backgroundSky.lift(),
            EffectMiddleware.realtimeSky.lift()
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
