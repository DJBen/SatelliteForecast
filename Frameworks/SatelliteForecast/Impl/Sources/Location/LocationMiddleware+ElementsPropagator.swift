//
//  LocationMiddleware+Propagator.swift
//  SatelliteForecastImplWiring
//
//  Created by Ben Lu on 4/20/22.
//

@preconcurrency import CombineRex
import SatelliteForecast
import Foundation
import SatelliteKit

extension EffectMiddleware where InputActionType == LocationAction, OutputActionType == ElementsPropagatorAction, StateType == Void, Dependencies == Void {
    /// This middleware triggers other `ElementsPropagatorAction`s from location action.
    public static var locationToElementsPropagator: EffectMiddleware<LocationAction, ElementsPropagatorAction, Void, Void> {
        EffectMiddleware.onAction { action, _, getState in
            switch action {
            case .selectLocation(_):
                return .just(.purgePassesAndSnapshots)
            default:
                return .doNothing
            }
        }
    }
}

extension EffectMiddleware where InputActionType == AppAction, OutputActionType == ElementsLoaderAction, StateType == AppState, Dependencies == Void {
    public static var loadAfterLocationUpdate: EffectMiddleware<AppAction, ElementsLoaderAction, AppState, Void> {
        EffectMiddleware.onAction { action, _, getState in
            switch action {
            case .locationOutput(.locationChanged(let location)):
                // If page is at first tab
                let state = getState()
                if state.navigationState.tab == .forecast && state.navigationState.passPredictionNavigationPath.isEmpty && state.elementsPropagatorResources.satelliteTrails.isEmpty {
                    let julianDateRange = JulianDateUtil.createJulianDateRange(now: Date().julianDate + state.debugMenu.effectiveOffset)
                    return .sequence([SatelliteCategory.iss, .tianhe].map { category in
                        .loadElements(
                            category: category,
                            fetchStrategy: .localWithin(21600 /* 6 hours */),
                            calculatePass: ElementsLoaderCalculatePassParam(
                                noradIndex: category.noradIndex!,
                                dateRange: julianDateRange,
                                observer: LatLonAlt(location: location)
                            )
                        )
                    })
                } else {
                    return .doNothing
                }
            default:
                return .doNothing
            }
        }
    }
}
