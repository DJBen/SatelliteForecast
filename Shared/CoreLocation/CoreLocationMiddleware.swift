//
//  CoreLocationMiddleware.swift
//  SatelliteForcast
//
//  Created by Ben Lu on 6/4/21.
//

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
