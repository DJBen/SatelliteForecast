//
//  SatelliteCategoryMiddleware+ElementsLoader.swift
//  SatelliteForecastPackage
//
//  Created by Sihao Lu on 6/27/25.
//

import Combine
@preconcurrency import CombineRex
@preconcurrency import SatelliteKit
import SatelliteForecast
import SatelliteForecastImpl

extension EffectMiddleware where
InputActionType == SatelliteCategoryViewAction,
OutputActionType == ElementsLoaderAction,
StateType == Void,
Dependencies == Void {

    public static var satelliteCategoryToElementLoader: EffectMiddleware<SatelliteCategoryViewAction, ElementsLoaderAction, Void, Void> {
        EffectMiddleware<SatelliteCategoryViewAction, ElementsLoaderAction, Void, Void>.onAction { action, _, getState in
            switch action {
            case .navigate(_):
                return .doNothing
            case .loadCategory(let category, julianDateRange: _, observer: _):
                return .just(
                    .loadElements(
                        category: category,
                        fetchStrategy: .localWithin(21600 /* 6 hours */)
                    )
                )
            }
        }
    }

    public func lift() -> AnyMiddleware<AppAction, AppAction, AppState> {
        return lift(
            inputAction: \.satelliteCategory,
            outputAction: AppAction.elementsLoader,
            state: { _ in }
        )
        .eraseToAnyMiddleware()
    }
}
