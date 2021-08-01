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
        Reducer<LocationAction, LocationState>.locationReducer
            .lift(action: \.location, state: \.locationState),
        Reducer<SatelliteLoaderAction, SatelliteLoaderState>.satelliteLoaderReducer
            .lift(action: \.satelliteLoader, state: \.satelliteLoaderState),
        Reducer<SatelliteOverviewViewAction, AppState>.satelliteOverviewReducer
            .lift(action: \.satelliteOverview),
        Reducer<SatelliteListViewAction, AppState>.satelliteListViewReducer
            .lift(action: \.satelliteListView),
        Reducer<AllPassesViewAction, AppState>.allPassesViewReducer
            .lift(action: \.allPassesView),
        Reducer<PassViewAction, AppState>.passViewReducer
            .lift(action: \.passView),
        Reducer<SatelliteElevationGraphAction, SatelliteElevationGraphResources>.satelliteElevationGraphReducer
            .lift(action: \.satelliteElevationGraph, state: \.satelliteElevationGraphResources),
        Reducer<SkyChartAction, SkyChartResources>.skyChartReducer
            .lift(action: \.skyChart, state: \.skyChartState),
        Reducer<TLEPropagatorAction, AppState>.tlePropagatorReducer
            .lift(action: \.tlePropagator),
        Reducer<TimerAction, AppState>.timerReducer
            .lift(action: \.timer),
        Reducer<DebugMenuAction, AppState>.debugMenuReducer
            .lift(action: \.debugMenu),
        Reducer<AppAction, AppState>.appStateReducer
    ]
    .reduce(Reducer<AppAction, AppState>.identity, <>)

    static func middlewareBuilder(
        satelliteLoader: SatelliteLoader
    ) -> AnyMiddleware<AppAction, AppAction, AppState> {

        let composedMiddleware = LocationMiddleware().lifted

        <> EffectMiddleware.locationLogger.lifted

        <> EffectMiddleware.satelliteLoader(satelliteLoader)
            .lifted
            .inject(
                SatelliteLoaderDependencies()
            )
            .eraseToAnyMiddleware()

        <> EffectMiddleware.satelliteOverview
            .lift(
                inputAction: { $0.satelliteOverview }
            )
            .eraseToAnyMiddleware()

        <> EffectMiddleware.satelliteListView(satelliteLoader: satelliteLoader)
            .lift(
                inputAction: { $0.satelliteListView }
            )
            .eraseToAnyMiddleware()

        <> EffectMiddleware.singleSatelliteWrappingView
            .lift(
                inputAction: { $0.singleSatelliteWrappingView }
            )
            .eraseToAnyMiddleware()

        <> EffectMiddleware.allPassesView
            .lift(
                inputAction: { $0.allPassesView }
            )
            .eraseToAnyMiddleware()

        <> EffectMiddleware.skyChart
            .lift(
                inputAction: { $0.skyChart },
                outputAction: AppAction.skyChart
            )
            .eraseToAnyMiddleware()

        <> EffectMiddleware.satelliteElevationGraph
            .lift(
                inputAction: { $0.satelliteElevationGraph },
                outputAction: AppAction.satelliteElevationGraph
            )
            .eraseToAnyMiddleware()

        <> EffectMiddleware.timer
            .lift(
                inputAction: { $0.timer },
                outputAction: AppAction.timer
            )
            .eraseToAnyMiddleware()

        <> EffectMiddleware.debugMenu.lifted

        // <> LoggerMiddleware()

        return composedMiddleware.eraseToAnyMiddleware()
    }

    private init() {
        let satelliteLoader: SatelliteLoader = SatelliteLoaderImpl(session: URLSession.shared)

        super.init(
            subject: .combine(initialValue: .empty),
            reducer: Store.reducer,
            middleware: Store.middlewareBuilder(satelliteLoader: satelliteLoader)
        )
    }
}
