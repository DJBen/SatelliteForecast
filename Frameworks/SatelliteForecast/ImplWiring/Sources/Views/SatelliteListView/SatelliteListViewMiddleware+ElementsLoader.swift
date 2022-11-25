//
//  SatelliteListViewMiddleware+ElementsLoader.swift
//  SatelliteForecastImplWiring
//
//  Created by Ben Lu on 4/8/22.
//

import CombineRex
import CombineRextensions
import SatelliteForecastImpl

extension EffectMiddleware where InputActionType == SatelliteListViewAction, OutputActionType == ElementsLoaderAction, StateType == Void, Dependencies == Void {
    /// This middleware triggers `calculatePass` event after satellite has been loaded
    public static var satelliteListToElementLoader: EffectMiddleware<SatelliteListViewAction, ElementsLoaderAction, Void, Void> {
        EffectMiddleware.onAction { action, dispatcher, getState in
            switch action {
            case .selectSatellite(_), .loadSatellite(_), .searchSatellites(_, category: _):
                return .doNothing
            case .retryLoadingSatelliteList(let category):
                return .just(
                    .loadElements(
                        category: category,
                        fetchStrategy: .localWithin(7200)
                    )
                )
            }
        }
    }

    public func lift() -> AnyMiddleware<AppAction, AppAction, AppState> {
        lift(
            inputAction: \.satelliteListView,
            outputAction: AppAction.elementsLoader,
            state: { _ in }
        )
        .eraseToAnyMiddleware()
    }
}
