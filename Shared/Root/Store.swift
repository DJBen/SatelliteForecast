//
//  Store.swift
//  SatelliteForcast
//
//  Created by Ben Lu on 6/4/21.
//

import SatelliteKit
import SatelliteForcastCore
import SwiftRex
import CombineRex

class Store: ReduxStoreBase<AppAction, AppState> {
    static let shared = Store()

    private let reducers: [Reducer<AppAction, AppState>] = [
        Reducer<CoreLocationAction, CoreLocationState>.coreLocationReducer
            .lift(action: \.coreLocation, state: \.coreLocationState),
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
        Reducer<AppAction, AppState>.appStateReducer
    ]

    let middleware: ComposedMiddleware<AppAction, AppAction, AppState> =
        CoreLocationMiddleware().lifted

        <> EffectMiddleware.coreLocationLogger.lifted

        <> EffectMiddleware.satelliteLoader
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

        <> EffectMiddleware.satelliteListView
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

        <> EffectMiddleware<SatelliteElevationGraphAction, SatelliteElevationGraphAction, AppState, Void>.satelliteElevationGraph
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

        // <> LoggerMiddleware()

    private init() {
        super.init(
            subject: .combine(initialValue: .empty),
            reducer: reducers.reduce(Reducer<AppAction, AppState>.identity, <>),
            middleware: middleware
        )
    }
}
