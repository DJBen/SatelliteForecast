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

    private init() {
        super.init(
            subject: .combine(initialValue: .empty),
            reducer: Reducer<CoreLocationOutputAction, CoreLocationState>.coreLocationReducer
                .lift(action: \.coreLocationOutput, state: \.coreLocationState)

                <> Reducer<TLELoaderInputAction, TLELoaderState>.tleLoaderReducer
                .lift(action: \.tleLoaderInput, state: \.tleLoaderState)

                <> Reducer<TLELoaderOutputAction, TLELoaderState>.tleLoaderReducer
                .lift(action: \.tleLoaderOutput, state: \.tleLoaderState)

                <> Reducer<SatelliteListViewAction, AppState>.satelliteListViewReducer
                .lift(action: \.satelliteListView),
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
                    TLELoaderDependencies(
                        updateReferenceDate: Date()
                    )
                )

                <> EffectMiddleware.satelliteListView
                .lift(
                    inputAction: { $0.satelliteListView }
                )

//                <> LoggerMiddleware()
        )
    }
}
