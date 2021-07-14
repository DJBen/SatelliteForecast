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
    typealias InputActionType = CoreLocationAction
    typealias OutputActionType = CoreLocationAction
    typealias StateType = CoreLocationState

    var locationManager: CLLocationManager!
    var output: AnyActionHandler<CoreLocationAction>!

    func receiveContext(getState: @escaping GetState<CoreLocationState>, output: AnyActionHandler<CoreLocationAction>) {
        locationManager = CLLocationManager()
        locationManager.desiredAccuracy = kCLLocationAccuracyKilometer
        locationManager.distanceFilter = 1000
        locationManager.startMonitoringSignificantLocationChanges()
        locationManager.startUpdatingLocation()
        locationManager.delegate = self
        self.output = output

        // Output the initial authorization status
        output.dispatch(.authorizationDidChange(locationManager.authorizationStatus))
    }

    func handle(action: CoreLocationAction, from dispatcher: ActionSource, afterReducer: inout AfterReducer) {
        switch action {
        case .requestAuthorization:
            locationManager.requestWhenInUseAuthorization()
        case .authorizationDidChange(_):
            break
        case .locationChanged(_):
            break
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

fileprivate let logger = Logger(subsystem: "io.djben.coreLocation", category: "middleware")

extension EffectMiddleware where InputActionType == CoreLocationAction, OutputActionType == Never, StateType == Void, Dependencies == Void {
    static var coreLocationLogger: EffectMiddleware<CoreLocationAction, Never, Void, Void> {
        EffectMiddleware<CoreLocationAction, Never, Void, Void>
            .onAction { action, _, getState in
                switch action {
                case .requestAuthorization:
                    break
                case let .authorizationDidChange(authorizationStatus):
                    logger.info("[CoreLocation] authorization changed: \(authorizationStatus.rawValue))")
                case let .locationChanged(location):
                    logger.info("[CoreLocation] location changed: \(location)")
                }

                return .doNothing
            }
    }
}
