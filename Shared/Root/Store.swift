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
        Reducer<CoreLocationOutputAction, CoreLocationState>.coreLocationReducer
            .lift(action: \.coreLocationOutput, state: \.coreLocationState),
        Reducer<TLELoaderInputAction, TLELoaderState>.tleLoaderReducer
            .lift(action: \.tleLoaderInput, state: \.tleLoaderState),
        Reducer<TLELoaderOutputAction, TLELoaderState>.tleLoaderReducer
            .lift(action: \.tleLoaderOutput, state: \.tleLoaderState),
        Reducer<SatelliteListViewAction, AppState>.satelliteListViewReducer
            .lift(action: \.satelliteListView),
        Reducer<AllPassesViewAction, AppState>.allPassesViewReducer
            .lift(action: \.allPassesView),
        Reducer<PassViewAction, AppState>.passViewReducer
            .lift(action: \.passView),
        Reducer<SkyChartAction, SkyChartResources>.skyChartReducer
            .lift(action: \.skyChart, state: \.skyChartState),
        Reducer<TLEPropagatorAction, AppState>.tlePropagatorReducer
            .lift(action: \.tlePropagator),
        Reducer<TimerAction, AppState>.timerReducer
            .lift(action: \.timer)
    ]

    private init() {
        super.init(
            subject: .combine(initialValue: .empty),
            reducer: reducers.reduce(Reducer<AppAction, AppState>.identity, <>),
            middleware: CoreLocationMiddleware()
                .lift(
                    inputAction: \AppAction.coreLocationInput,
                    outputAction: AppAction.coreLocationOutput,
                    state: \.coreLocationState
                )

                <> EffectMiddleware.coreLocationLogger
                .lift(
                    inputAction: { $0.coreLocationOutput },
                    outputAction: { _ -> AppAction in },
                    state: { _ in }
                )

                <> EffectMiddleware.tleLoader
                .lift(
                    inputAction: \AppAction.tleLoaderInput,
                    outputAction: AppAction.tleLoaderOutput,
                    state: \AppState.tleLoaderState
                )
                .inject(
                    TLELoaderDependencies()
                )

                <> EffectMiddleware.satelliteListView
                .lift(
                    inputAction: { $0.satelliteListView }
                )

                <> EffectMiddleware.allPassesView
                .lift(
                    inputAction: { $0.allPassesView }
                )

                <> EffectMiddleware.skyChart
                .lift(
                    inputAction: { $0.skyChart },
                    outputAction: AppAction.skyChart
                )

                <> EffectMiddleware.timer
                .lift(
                    inputAction: { $0.timer },
                    outputAction: AppAction.timer
                )

//                <> LoggerMiddleware()
        )
    }
}
