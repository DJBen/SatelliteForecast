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

    public func lift() -> AnyMiddleware<AppAction, AppAction, AppState> {
        return lift(
            inputAction: \.satelliteCategory,
            outputAction: AppAction.elementsLoader,
            state: { _ in }
        )
        .eraseToAnyMiddleware()
    }
}
