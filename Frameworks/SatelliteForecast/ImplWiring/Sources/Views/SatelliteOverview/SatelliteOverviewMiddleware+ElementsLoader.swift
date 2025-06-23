//
//  SatelliteOverviewMiddleware+ElementsLoader.swift
//  SatelliteForecastImplWiring
//
//  Created by Ben Lu on 4/9/22.
//

import Combine
@preconcurrency import CombineRex
@preconcurrency import SatelliteKit
import SatelliteForecast
import SatelliteForecastImpl

extension EffectMiddleware where
InputActionType == SatelliteOverviewViewAction,
OutputActionType == ElementsLoaderAction,
StateType == Void,
Dependencies == Void {

    public static var satelliteOverviewToElementLoader: EffectMiddleware<SatelliteOverviewViewAction, ElementsLoaderAction, Void, Void> {
        EffectMiddleware<SatelliteOverviewViewAction, ElementsLoaderAction, Void, Void>.onAction { action, _, getState in
            switch action {
            case .navigate(_):
                return .doNothing
            case .loadSatelliteOfSpecialInterest(let satellite, julianDateRange: let julianDateRange, observer: let observer),
                    .selectSatelliteOfSpecialInterest(let satellite, julianDateRange: let julianDateRange, observer: let observer):
                let category = satellite.noradIndex == 25544 ? SatelliteCategory.iss : .tianhe
                return .just(
                    .loadElements(
                        category: category,
                        fetchStrategy: .localWithin(21600 /* 6 hours */),
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
            inputAction: \.satelliteOverview,
            outputAction: AppAction.elementsLoader,
            state: { _ in }
        )
        .eraseToAnyMiddleware()
    }
}
