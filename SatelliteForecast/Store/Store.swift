//
//  Store.swift
//  SatelliteForecast
//
//  Created by Ben Lu on 6/4/21.
//

import SatelliteKit
import SatelliteForecastCore
import SwiftRex
import CombineRex

class Store: ReduxStoreBase<AppAction, AppState> {
    static let shared = Store()

    static let reducer: Reducer<AppAction, AppState> = [
        Reducer<LocationAction, AppState>.locationReducer.lift(action: \.location),
        Reducer<NotificationAction, AppState>.notificationReducer.lift(action: \.notification),
        Reducer<TLELoaderAction, TLELoaderState>.tleLoaderReducer.lift(),
        Reducer<TLELoaderOutput, TLELoaderState>.tleLoaderOutputReducer.lift(),
        Reducer.satelliteOverviewReducer.lift(),
        Reducer<SatelliteListViewAction, AppState>.satelliteListViewReducer.lift(action: \.satelliteListView),
        Reducer<AllPassesViewAction, AppState>.allPassesViewReducer.lift(action: \.allPassesView),
        Reducer<PassViewAction, AppState>.passViewReducer.lift(action: \.passView),
        Reducer<SatelliteElevationGraphAction, SatelliteElevationGraphResources>.satelliteElevationGraphReducer
        .lift(
            action: \.satelliteElevationGraph,
            state: \.satelliteElevationGraphResources
        ),
        Reducer<SkyChartOutput, SkyChartResources>.skyChartOutputReducer.lift(),
        Reducer<TLEPropagatorAction, AppState>.tlePropagatorReducer.lift(action: \.tlePropagator),
        Reducer<TimerAction, AppState>.timerReducer.lift(action: \.timer),
        Reducer<DebugMenuAction, DebugMenuState>.debugMenuReducer.lift(),
        Reducer.backgroundSkyReducer.lift(),
        Reducer.realtimeSkyReducer.lift(),
        Reducer.realtimeSkyOutputReducer.lift(),
        Reducer.rootViewReducer.lift()
    ]
    .reduce(Reducer<AppAction, AppState>.identity, <>)

    static func middlewareBuilder(
        tleLoader: TLELoader
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
            EffectMiddleware.tleLoader(tleLoader)
                .lift()
                .inject(
                    TLELoaderDependencies()
                )
                .eraseToAnyMiddleware(),
            EffectMiddleware.calculatePassAfterTLELoader.lift(),
            EffectMiddleware.selectSatelliteAfterTLELoader.lift(),
            EffectMiddleware.selectSpecialSatelliteAfterTLELoader.lift(),
            EffectMiddleware.satelliteOverview.lift(),
            EffectMiddleware.satelliteListView(tleLoader: tleLoader)
                .lift(
                    inputAction: \.satelliteListView
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
        let tleLoader: TLELoader
        if ProcessInfo.processInfo.environment["USE_LOCAL_TLES"] == "YES" {
            print("[TLE Loader] Using local TLE loader")
            #if DEBUG
            tleLoader = LocalTLELoader()
            #else
            tleLoader = TLELoaderImpl(session: URLSession.shared)
            #endif
        } else {
            tleLoader = TLELoaderImpl(session: URLSession.shared)
        }

        super.init(
            subject: .combine(initialValue: .empty),
            reducer: Store.reducer,
            middleware: Store.middlewareBuilder(tleLoader: tleLoader),
            emitsValue: .whenDifferent
        )
    }
}
