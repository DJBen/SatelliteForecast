//
//  ElementsLoaderMiddleware+ElementPropagator.swift
//  SatelliteForecastImplWiring
//
//  Created by Ben Lu on 4/1/22.
//

@preconcurrency import CombineRex
@preconcurrency import CombineRextensions
import SatelliteForecast
import SatelliteForecastImpl

extension EffectMiddleware where InputActionType == ElementsLoaderOutput, OutputActionType == ElementsPropagatorAction, StateType == ElementsLoaderState, Dependencies == Void {
    /// This middleware triggers `calculatePass` event after satellite has been loaded
    public static var elementsLoaderToElementsPropagator: EffectMiddleware<ElementsLoaderOutput, ElementsPropagatorAction, ElementsLoaderState, Void> {
        EffectMiddleware.onAction { action, dispatcher, getState in
            switch action {
            case .loadedSatelliteElements(_, let satelliteInfoMap, _, _, let calculatePass):
                guard let calculatePass = calculatePass, let satelliteInfo = satelliteInfoMap[calculatePass.noradIndex] else {
                    return .doNothing
                }

                return .just(
                    .calculatePasses(
                        CalculatePassesParams(
                            selectedNoradIndex: calculatePass.noradIndex,
                            satelliteInfo: satelliteInfo,
                            julianDateRange: calculatePass.dateRange,
                            observer: calculatePass.observer
                        )
                    ),
                    from: dispatcher
                )

            case .failedLoadingElements(_, _):
                return .doNothing
            }
        }
    }
}

extension EffectMiddleware where InputActionType == ElementsLoaderOutput, OutputActionType == ElementsPropagatorAction, StateType == ElementsLoaderState, Dependencies == Void {
    public func lift() -> AnyMiddleware<AppAction, AppAction, AppState> {
        lift(
            inputAction: \.elementsLoaderOutput,
            outputAction: AppAction.elementsPropagator,
            state: ElementsLoaderState.project(appState:)
        )
        .eraseToAnyMiddleware()
    }
}
