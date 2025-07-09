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
import UIKit

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
            case .onAppear(let julianDateRange, let observer):
                return .sequence([SatelliteCategory.iss, .tianhe].map { category in
                    .loadElements(
                        category: category,
                        fetchStrategy: .localWithin(21600 /* 6 hours */),
                        calculatePass: observer.map { observer in
                            ElementsLoaderCalculatePassParam(
                                noradIndex: category.noradIndex!,
                                dateRange: julianDateRange,
                                observer: observer
                            )
                        }
                    )
                })
            case .selectSatellite(let specialSatellite, let julianDateRange, let observer):
                return .just(
                    .loadElements(
                        category: specialSatellite.category,
                        fetchStrategy: .localWithin(21600 /* 6 hours */),
                        calculatePass: observer.map { observer in
                            ElementsLoaderCalculatePassParam(
                                noradIndex: specialSatellite.category.noradIndex!,
                                dateRange: julianDateRange,
                                observer: observer
                            )
                        }
                    )
                )
            case .deeplinkToLocationSelection:
                return .doNothing
            case .showLocationSettings:
                UIApplication.shared.open(
                    URL(string: UIApplication.openSettingsURLString)!,
                    options: [:],
                    completionHandler: nil
                )
                return .doNothing
            }
        }
    }
}
