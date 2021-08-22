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
import MapKit
import SatelliteKit

class LocationMiddleware: NSObject, Middleware {
    typealias InputActionType = LocationAction
    typealias OutputActionType = AppAction
    typealias StateType = LocationState

    var locationManager: CLLocationManager!
    var geocoder: CLGeocoder!
    var searchCompleter: MKLocalSearchCompleter!

    private var getState: GetState<StateType>!
    private var output: AnyActionHandler<AppAction>!

    func receiveContext(getState: @escaping GetState<LocationState>, output: AnyActionHandler<AppAction>) {
        locationManager = CLLocationManager()
        locationManager.desiredAccuracy = kCLLocationAccuracyKilometer
        locationManager.distanceFilter = 2000
        locationManager.startMonitoringSignificantLocationChanges()
        locationManager.startUpdatingLocation()
        locationManager.delegate = self

        geocoder = CLGeocoder()
        searchCompleter = MKLocalSearchCompleter()
        searchCompleter.delegate = self

        self.getState = getState
        self.output = output

        // Output the initial authorization status
        output.dispatch(.location(.authorizationDidChange(locationManager.authorizationStatus)))
    }

    func handle(action: LocationAction, from dispatcher: ActionSource, afterReducer: inout AfterReducer) {
        afterReducer = .do { [weak self] in
            switch action {
            case .requestAuthorization:
                self?.locationManager.requestWhenInUseAuthorization()
            case let .requestReverseGeocoding(location):
                self?.geocoder.reverseGeocodeLocation(location) { placemarks, error in
                    if let placemarks = placemarks {
                        self?.output.dispatch(.location(.reverseGeocodingFinished(.success(placemarks))))
                    } else if let error = error {
                        self?.output.dispatch(.location(.reverseGeocodingFinished(.failure(error))))
                    }
                }
            case let .requestAutoCompletion(searchTerm):
                self?.searchCompleter.queryFragment = searchTerm
            case let .selectLocation(selection):
                switch selection {
                case .currentLocation:
                    if let currentLocation = self?.getState().currentLocation {
                        self?.output.dispatch(.location(.persistLocation(currentLocation)))
                    } else {
                        UIApplication.shared.open(
                            URL(string: UIApplication.openSettingsURLString)!,
                            options: [:],
                            completionHandler: nil
                        )
                        return
                    }
                case let .custom(_, placemark):
                    if let location = placemark.location {
                        self?.output.dispatch(.location(.persistLocation(location)))
                    }
                    break
                }
                self?.output.dispatch(.tlePropagator(.purgePassesAndSnapshots))
                self?.output.dispatch(.navigation(.dismissLocationSettings))
            case .authorizationDidChange(_):
                break
            case let .locationChanged(location):
                self?.output.dispatch(.location(.requestReverseGeocoding(location)))
                
                if self?.getState().selection == .currentLocation {
                    self?.output.dispatch(.location(.persistLocation(location)))
                }
            case .reverseGeocodingFinished(_):
                break
            case .autocompletionFinished(_):
                break
            case let .persistLocation(location):
                let encoder = JSONEncoder()
                let data = try! encoder.encode(LatLonAlt(location: location))
                UserDefaults.standard.set(data, forKey: "lastUsedLocation")
            }
        }
    }
}

extension LocationMiddleware: CLLocationManagerDelegate {
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        output.dispatch(.location(.authorizationDidChange(manager.authorizationStatus)))
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let lastLocation = locations.last else {
            return
        }
        output.dispatch(.location(.locationChanged(lastLocation)))
    }
}

extension LocationMiddleware: MKLocalSearchCompleterDelegate {
    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        output.dispatch(.location(.autocompletionFinished(.success(completer.results))))
    }

    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        output.dispatch(.location(.autocompletionFinished(.failure(error))))
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
                case .requestAutoCompletion(_):
                    break
                case .selectLocation(_):
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
                        logger.error("[Location] reverse geocoding failed \(error.localizedDescription)")
                    }
                case let .autocompletionFinished(result):
                    switch result {
                    case .success(_):
                        break
                    case let .failure(error):
                        logger.error("[Map] autocompletion failed \(error.localizedDescription)")
                    }
                case let .persistLocation(location):
                    logger.info("Persisted last location \(location)")
                }
            return .doNothing
        }
    }
}
