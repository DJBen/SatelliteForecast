//
//  SatelliteListViewMiddleware+ElementsLoader.swift
//  SatelliteForecastImplWiring
//
//  Created by Ben Lu on 4/8/22.
//

@preconcurrency import CombineRex
@preconcurrency import CombineRextensions
import SatelliteForecast

extension EffectMiddleware where InputActionType == SatelliteListViewAction, OutputActionType == ElementsLoaderAction, StateType == Void, Dependencies == Void {
    /// This middleware triggers `calculatePass` event after satellite has been loaded
    public static var satelliteListToElementLoader: EffectMiddleware<SatelliteListViewAction, ElementsLoaderAction, Void, Void> {
        EffectMiddleware.onAction { action, dispatcher, getState in
            switch action {
            case .selectSatellite(_, category: _), .loadSatellite(_), .searchSatellites(_, category: _):
                return .doNothing
            case .retryLoadingSatelliteList(let category):
                return .just(
                    .loadElements(
                        category: category,
                        fetchStrategy: .localWithin(21600 /* 6 hours */)
                    )
                )
            case .reloadSatellites(let category):
                category.removeCachedElements()
                return .just(
                    .loadElements(
                        category: category,
                        fetchStrategy: .onlineFirst
                    )
                )
            }
        }
    }
}
