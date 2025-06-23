//
//  SatelliteListViewMiddleware+ElementsPropagator.swift
//  SatelliteForecastImplWiring
//
//  Created by Ben Lu on 4/8/22.
//

@preconcurrency import CombineRex
@preconcurrency import CombineRextensions
import SatelliteForecast
import SatelliteForecastImpl

extension EffectMiddleware where InputActionType == SatelliteListViewAction, OutputActionType == ElementsPropagatorAction, StateType == Void, Dependencies == Void {
    /// This middleware triggers `calculatePass` event after selecting a satellite
    public static var satelliteListViewToElementPropagator: EffectMiddleware<SatelliteListViewAction, ElementsPropagatorAction, Void, Void> {
        EffectMiddleware.onAction { action, dispatcher, getState in
            switch action {
            case .loadSatellite(let params):
                guard let params = params else {
                    return .doNothing
                }

                guard let observer = params.observer else {
                    return .doNothing
                }

                return .just(
                    .calculatePasses(
                        .init(
                            selectedNoradIndex: params.noradIndex,
                            satelliteInfo: params.satelliteInfo,
                            julianDateRange: params.julianDateRange,
                            observer: observer
                        )
                    )
                )
            case .selectSatellite(_, category: _):
                return .doNothing
            case .retryLoadingSatelliteList:
                return .doNothing
            case .searchSatellites(_, category: _):
                return .doNothing
            }
        }
    }

    public func lift() -> AnyMiddleware<AppAction, AppAction, AppState> {
        lift(
            inputAction: \.satelliteListView,
            outputAction: AppAction.elementsPropagator,
            state: { _ in }
        )
        .eraseToAnyMiddleware()
    }
}
