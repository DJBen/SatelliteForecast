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
            case .selectSatellite(_), .loadSatellite(_):
                return .doNothing
            case .satelliteSearchTextChanged(_):
                return .doNothing
            case .retryLoadingSatelliteList(let category):
                return .just(
                    .loadElements(
                        category: category
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
