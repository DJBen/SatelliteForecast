//
//  SatelliteOverviewMiddleware+ElementsLoader.swift
//  SatelliteForecastApp
//
//  Created by Ben Lu on 4/9/22.
//

import Combine
import CombineRex
import SatelliteKit
import SatelliteForecastImpl

extension EffectMiddleware where
InputActionType == SatelliteOverviewViewAction,
OutputActionType == ElementsLoaderAction,
StateType == Void,
Dependencies == Void {

    static var satelliteOverviewToElementLoader: EffectMiddleware<SatelliteOverviewViewAction, ElementsLoaderAction, Void, Void> {
        EffectMiddleware<SatelliteOverviewViewAction, ElementsLoaderAction, Void, Void>.onAction { action, _, getState in
            switch action {
            case .selectNavigationItem(let item, let julianDateRange, let observer):
                switch item {
                case .specialSatellite(let satelliteOption):
                    return .just(
                        .loadElements(
                            category: .brightest100,
                            calculatePass: observer.map { observer in
                                ElementsLoaderCalculatePassParam(
                                    noradIndex: satelliteOption.rawValue,
                                    dateRange: julianDateRange,
                                    observer: observer
                                )
                            }
                        )
                    )
                case .category(let category):
                    return .just(
                        .loadElements(category: category)
                    )
                default:
                    return .doNothing
                }
            }
        }
    }

    func lift() -> AnyMiddleware<AppAction, AppAction, AppState> {
        return lift(
            inputAction: \.satelliteOverview,
            outputAction: AppAction.elementsLoader,
            state: { _ in }
        )
        .eraseToAnyMiddleware()
    }
}
