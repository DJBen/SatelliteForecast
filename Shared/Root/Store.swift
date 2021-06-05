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
                .lift(action: \.coreLocationOutput, state: \.coreLocationState),
            middleware: CoreLocationMiddleware()
                .lift(
                    inputAction: \AppAction.coreLocationInput,
                    outputAction: AppAction.coreLocationOutput,
                    state: \.coreLocationState
                )

                <> EffectMiddleware.tleLoader
                .lift(
                    inputAction: \AppAction.tleLoaderInput,
                    outputAction: AppAction.tleLoaderOutput,
                    state: \AppState.tleLoaderState
                )
                .inject(TLELoaderDependencies())

//                <> LoggerMiddleware()
        )
    }
}
