//
//  CoreLocationMiddleware.swift
//  SatelliteForcast
//
//  Created by Ben Lu on 6/4/21.
//

import os
import CombineRex
import SwiftRex
import CoreLocation

class CoreLocationMiddleware: NSObject, Middleware {
    typealias InputActionType = CoreLocationInputAction
    typealias OutputActionType = CoreLocationOutputAction
    typealias StateType = CoreLocationState

    var locationManager: CLLocationManager!
    var output: AnyActionHandler<CoreLocationOutputAction>!

    func receiveContext(getState: @escaping GetState<CoreLocationState>, output: AnyActionHandler<CoreLocationOutputAction>) {
        locationManager = CLLocationManager()
        locationManager.desiredAccuracy = kCLLocationAccuracyThreeKilometers
        locationManager.startMonitoringSignificantLocationChanges()
        locationManager.startUpdatingLocation()
        locationManager.delegate = self
        self.output = output

        // Output the initial authorization status
        output.dispatch(.authorizationDidChange(locationManager.authorizationStatus))
    }

    func handle(action: CoreLocationInputAction, from dispatcher: ActionSource, afterReducer: inout AfterReducer) {
        switch action {
        case .requestAuthorization:
            locationManager.requestWhenInUseAuthorization()
        }
    }
}

extension CoreLocationMiddleware: CLLocationManagerDelegate {
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        output.dispatch(.authorizationDidChange(manager.authorizationStatus))
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let lastLocation = locations.last else {
            return
        }
        output.dispatch(.locationChanged(lastLocation))
    }
}

extension EffectMiddleware where InputActionType == CoreLocationOutputAction, OutputActionType == Never, StateType == Void, Dependencies == Void {
    static var coreLocationLogger: EffectMiddleware<CoreLocationOutputAction, Never, Void, Void> {
        EffectMiddleware<CoreLocationOutputAction, Never, Void, Void>
            .onAction { action, _, getState in
                switch action {
                case let .authorizationDidChange(authorizationStatus):
                    os_log("[CoreLocation] authorization changed: \(authorizationStatus.rawValue))")
                case let .locationChanged(location):
                    os_log("[CoreLocation] location changed: \(location)")
                }

                return .doNothing
            }
    }
}
