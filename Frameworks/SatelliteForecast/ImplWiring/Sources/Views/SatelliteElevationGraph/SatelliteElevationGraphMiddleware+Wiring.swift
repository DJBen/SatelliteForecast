//
//  SatelliteElevationGraphMiddleware+Wiring.swift
//  SatelliteForecastImplWiring
//
//  Created by Ben Lu on 4/4/22.
//

@preconcurrency import CombineRex
import SatelliteForecast
import SatelliteForecastImpl

extension EffectMiddleware where InputActionType == SatelliteElevationGraphAction, OutputActionType == SatelliteElevationGraphAction, StateType == SatelliteElevationGraphState, Dependencies == Void {
    public func lift() -> AnyMiddleware<AppAction, AppAction, AppState> {
        lift(
            inputAction: \.satelliteElevationGraph,
            outputAction: AppAction.satelliteElevationGraph,
            state: SatelliteElevationGraphState.project(appState:)
        )
        .eraseToAnyMiddleware()
    }
}
