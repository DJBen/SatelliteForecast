//
//  LocationMiddleware.swift
//  SatelliteForecast
//
//  Created by Ben Lu on 6/4/21.
//

import os
import CombineRex
import SwiftRex
import CoreLocation

class LocationMiddleware: NSObject, Middleware {
    typealias InputActionType = LocationAction
    typealias OutputActionType = LocationAction
    typealias StateType = LocationState

    var locationManager: CLLocationManager!
    var geocoder: CLGeocoder!
    var output: AnyActionHandler<LocationAction>!

    func receiveContext(getState: @escaping GetState<LocationState>, output: AnyActionHandler<LocationAction>) {
        locationManager = CLLocationManager()
        locationManager.desiredAccuracy = kCLLocationAccuracyKilometer
        locationManager.distanceFilter = 1000
        locationManager.startMonitoringSignificantLocationChanges()
        locationManager.startUpdatingLocation()
        locationManager.delegate = self

        geocoder = CLGeocoder()

        self.output = output

        // Output the initial authorization status
        output.dispatch(.authorizationDidChange(locationManager.authorizationStatus))
    }

    func handle(action: LocationAction, from dispatcher: ActionSource, afterReducer: inout AfterReducer) {
        afterReducer = .do { [weak self] in
            switch action {
            case .requestAuthorization:
                self?.locationManager.requestWhenInUseAuthorization()
            case let .requestReverseGeocoding(location):
                self?.geocoder.reverseGeocodeLocation(location) { placemarks, error in
                    if let placemarks = placemarks {
                        self?.output.dispatch(.reverseGeocodingFinished(.success(placemarks)))
                    } else if let error = error {
                        self?.output.dispatch(.reverseGeocodingFinished(.failure(error)))
                    }
                }
            case .authorizationDidChange(_):
                break
            case let .locationChanged(location):
                self?.output.dispatch(.requestReverseGeocoding(location))
            case .reverseGeocodingFinished(_):
                break
            }
        }
    }
}

extension LocationMiddleware: CLLocationManagerDelegate {
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

fileprivate let logger = Logger(subsystem: "io.djben.location", category: "middleware")

extension EffectMiddleware where InputActionType == LocationAction, OutputActionType == Never, StateType == Void, Dependencies == Void {
    static var locationLogger: EffectMiddleware<LocationAction, Never, Void, Void> {
        EffectMiddleware<LocationAction, Never, Void, Void>
            .onAction { action, _, getState in
                switch action {
                case .requestAuthorization:
                    break
                case .requestReverseGeocoding(_):
                    break
                case let .authorizationDidChange(authorizationStatus):
                    logger.info("[Location] authorization changed: \(authorizationStatus.rawValue))")
                case let .locationChanged(location):
                    logger.info("[Location] location changed: \(location)")
                case let .reverseGeocodingFinished(result):
                    switch result {
                    case let .success(placemarks):
                        logger.info("[Location] reverse geocoded to \(placemarks)")
                    case let .failure(error):
                        logger.error("\(error.localizedDescription)")
                    }
                }

                return .doNothing
            }
    }
}
