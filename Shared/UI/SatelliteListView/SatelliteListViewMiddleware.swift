//
//  SatelliteListViewMiddleware.swift
//  SatelliteForcast
//
//  Created by Ben Lu on 6/5/21.
//

import Foundation
import Combine
import CombineRex
import SatelliteKit

extension EffectMiddleware where
    InputActionType == SatelliteListViewAction,
    OutputActionType == AppAction,
    StateType == SatelliteListViewState,
    Dependencies == Void {

    static var satelliteListView: EffectMiddleware<SatelliteListViewAction, AppAction, SatelliteListViewState, Void> {
        EffectMiddleware<SatelliteListViewAction, AppAction, SatelliteListViewState, Void>
            .onAction { (action, _, getState) -> Effect<Void, AppAction> in
                switch action {
                case .onAppear:
                    return .sequence(
                        .coreLocationInput(.requestAuthorization),
                        .tleLoaderInput(.loadTLECategory(.brightest100))
                    )
                case .selectSatellite:
                    return .doNothing
                }
            }
    }
}
