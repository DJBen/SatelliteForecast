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
            case .selectSatelliteOfSpecialInterest(let satellite, julianDateRange: let julianDateRange, observer: let observer):
                guard let satellite = satellite else {
                    return .doNothing
                }
                return .just(
                    .loadElements(
                        category: .brightest100,
                        calculatePass: observer.map { observer in
                            ElementsLoaderCalculatePassParam(
                                noradIndex: satellite.noradIndex,
                                dateRange: julianDateRange,
                                observer: observer
                            )
                        }
                    )
                )
            case .selectCategory(let category, julianDateRange: _, observer: _):
                guard let category = category else {
                    return .doNothing
                }
                return .just(
                    .loadElements(category: category)
                )
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
