//
//  Store.swift
//  SatelliteForecast
//
//  Created by Ben Lu on 6/4/21.
//

import Foundation
@preconcurrency import SatelliteKit
import SatelliteForecast
import SatelliteForecastImpl
import SatelliteForecastImplWiring
@preconcurrency import SwiftRex
@preconcurrency import CombineRex

class Store: ReduxStoreBase<AppAction, AppState> {
    static let shared = Store()

    static let reducer: Reducer<AppAction, AppState> = [
        Reducer<AppDelegateAction, AppState>.appDelegateReducer.lift(action: \.appDelegate),
        Reducer.locationReducer.lift(),
        Reducer.locationOutputReducer.lift(),
        Reducer<NotificationAction, AppState>.notificationReducer.lift(action: \.notification),
        Reducer.elementsLoaderReducer.lift(),
        Reducer.elementsLoaderOutputReducer.lift(),
        Reducer.satelliteOverviewReducer.lift(),
        Reducer.satelliteCategoryReducer.lift(),
        Reducer.settingsOverviewReducer.lift(),
        Reducer.satelliteListViewReducer.lift(),
        Reducer.satelliteListOutputReducer.lift(),
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
        elementsLoader: ElementsLoader,
        currentDateProvider: @escaping () -> Date
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
                NotificationMiddlewareDependencies(
                    dateProvider: currentDateProvider
                )
            )
            .eraseToAnyMiddleware(),
            EffectMiddleware.loadAfterLocationUpdate.lift(
                outputAction: AppAction.elementsLoader
            )
            .eraseToAnyMiddleware(),
            EffectMiddleware.locationChainer.lift(),
            EffectMiddleware.locationToElementsPropagator.lift(),
            EffectMiddleware.locationToRealtimeSky.lift(),
            EffectMiddleware.locationOutputLogger.lift(),
            EffectMiddleware.elementsLoader.lift(
                dependencies: ElementsLoaderDependencies(
                    elementsLoader: elementsLoader,
                    dateProvider: currentDateProvider
                )
            ),
            EffectMiddleware.elementsPropagator.lift(),
            EffectMiddleware.elementsPropagatorChainer.lift(),
            EffectMiddleware.elementsLoaderToElementsPropagator.lift(),
            EffectMiddleware.elementsLoaderToSatelliteList.lift(),
            EffectMiddleware.selectSpecialSatelliteAfterElementsLoader.lift(),
            EffectMiddleware.rootViewElementsLoader.lift(),
            EffectMiddleware.satelliteOverviewToElementLoader.lift(),
            EffectMiddleware.satelliteCategoryToElementLoader.lift(),
            EffectMiddleware.satelliteList.lift(),
            EffectMiddleware.satelliteListViewToElementPropagator.lift(),
            EffectMiddleware.satelliteListToElementLoader.lift(),
            EffectMiddleware.singleSatelliteWrappingViewToElementsLoader.lift(),
            EffectMiddleware.allPassesViewToElementsPropagator.lift(),
            EffectMiddleware.allPassesViewToNotification.lift(),
            EffectMiddleware.skyChart.lift(),
            EffectMiddleware.satelliteElevationGraph.lift(),
            EffectMiddleware.alarmSettingsViewToNotification.lift(),
            EffectMiddleware.debugMenu.lift(
                dependencies: DebugMenuMiddlewareDependencies(
                    dateProvider: currentDateProvider
                )
            ),
            EffectMiddleware.backgroundSky.lift(),
            EffectMiddleware.realtimeSky.lift(),
            EffectMiddleware.realtimeSkyToElementsLoader.lift(),
            EffectMiddleware.passAlarmSettingsToNotification.lift(),
            EffectMiddleware.loggerMiddleware.eraseToAnyMiddleware(),
        ]

        return middlewares.reduce(
            ComposedMiddleware<AppAction, AppAction, AppState>.identity,
            <>
        )
        .eraseToAnyMiddleware()
    }

    private init() {
        let elementsLoader: ElementsLoader
        let currentDateProvider: () -> Date = Date.init
        if ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1" {
            print("[Elements Loader] Using local Elements loader for previews")
            #if DEBUG
            elementsLoader = LocalElementsLoader()
            #else
            elementsLoader = ElementsLoaderImpl(
                session: URLSession.shared,
                fileManager: FileManager.default,
                currentDateProvider: currentDateProvider
            )
            #endif
        } else {
            elementsLoader = ElementsLoaderImpl(
                session: URLSession.shared,
                fileManager: FileManager.default,
                currentDateProvider: currentDateProvider
            )
        }

        super.init(
            subject: .combine(initialValue: .init()),
            reducer: Store.reducer,
            middleware: Store.buildMiddleware(
                elementsLoader: elementsLoader,
                currentDateProvider: currentDateProvider
            ),
            emitsValue: .whenDifferent
        )
    }
}
