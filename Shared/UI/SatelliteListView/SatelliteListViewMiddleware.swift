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
    StateType == AppState,
    Dependencies == Void {

    /// A middeware that listens to `SatelliteListViewAction`.
    /// - `onAppear`: It bootstraps the flow with some side effects including loading the TLEs and requesting core location authorization.
    /// - `selectSatellite(noradIndex)`: It asynchronously does two things:
    ///   - Generate a coarse ephemeris of the satellite over a long future period.
    ///   - Find all the passes in the same period, and generate a fine ephemeris during each pass.
    ///
    ///   Thus this effect will have two action outputs before it completes.
    static var satelliteListView: EffectMiddleware<SatelliteListViewAction, AppAction, AppState, Void> {
        EffectMiddleware<SatelliteListViewAction, AppAction, AppState, Void>
            .onAction { (action, _, getState) -> Effect<Void, AppAction> in
                switch action {
                case .onAppear:
                    return .sequence(
                        .coreLocationInput(.requestAuthorization),
                        .satelliteLoaderInput(.loadSatelliteCategory(.brightest100)),
                        .timer(.start)
                    )
                case .selectSatellite:
                    if let observer = getState().coreLocationState.location.map(LatLonAlt.init) {
                        return .just(.freezeObserverLocation(observer))
                    } else {
                        return .doNothing
                    }
                }
            }
    }
}
