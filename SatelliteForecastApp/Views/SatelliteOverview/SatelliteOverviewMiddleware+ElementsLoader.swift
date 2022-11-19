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
            case .navigate(_, julianDateRange: _, observer: _):
                return .doNothing
            case .loadSatelliteOfSpecialInterest(let satellite, julianDateRange: let julianDateRange, observer: let observer),
                    .selectSatelliteOfSpecialInterest(let satellite, julianDateRange: let julianDateRange, observer: let observer):
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
            case .loadCategory(let category, julianDateRange: _, observer: _):
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
