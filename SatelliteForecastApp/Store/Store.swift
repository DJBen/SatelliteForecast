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
        Reducer<LocationAction, AppState>.locationReducer.lift(action: \.location),
        Reducer<NotificationAction, AppState>.notificationReducer.lift(action: \.notification),
        Reducer<ElementsLoaderAction, ElementsLoaderState>.elementsLoaderReducer.lift(),
        Reducer<ElementsLoaderOutput, ElementsLoaderState>.elementsLoaderOutputReducer.lift(),
        Reducer.satelliteOverviewReducer.lift(),
        Reducer.settingsOverviewReducer.lift(),
        Reducer<SatelliteListViewAction, AppState>.satelliteListViewReducer.lift(action: \.satelliteListView),
        Reducer<AllPassesViewAction, AppState>.allPassesViewReducer.lift(action: \.allPassesView),
        Reducer<PassViewAction, AppState>.passViewReducer.lift(action: \.passView),
        Reducer<SatelliteElevationGraphAction, SatelliteElevationGraphResources>.satelliteElevationGraphReducer
        .lift(
            action: \.satelliteElevationGraph,
            state: \.satelliteElevationGraphResources
        ),
        Reducer.skyChartOutputReducer.lift(),
        Reducer<ElementsPropagatorAction, AppState>.elementsPropagatorReducer.lift(action: \.elementsPropagator),
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
            EffectMiddleware.locationLogger.lift(),
            EffectMiddleware.elementsLoader
                .lift()
                .inject(
                    ElementsLoaderDependencies(elementsLoader: elementsLoader)
                )
                .eraseToAnyMiddleware(),
            EffectMiddleware.calculatePassAfterElementsLoader.lift(),
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
            EffectMiddleware.allPassesView
                .lift(
                    inputAction: \.allPassesView
                )
                .eraseToAnyMiddleware(),
            EffectMiddleware.skyChart.lift(),
            EffectMiddleware.satelliteElevationGraph
                .lift(
                    inputAction: \.satelliteElevationGraph,
                    outputAction: AppAction.satelliteElevationGraph
                )
                .eraseToAnyMiddleware(),
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
