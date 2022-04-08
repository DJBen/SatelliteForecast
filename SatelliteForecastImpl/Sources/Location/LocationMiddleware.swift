//
//  LocationMiddleware.swift
//  SatelliteForecastImpl
//
//  Created by Ben Lu on 6/4/21.
//

import os
import CombineRex
import CoreLocation
import MapKit
import SatelliteForecast
import SatelliteKit
import SwiftRex

public class LocationMiddleware: NSObject, MiddlewareProtocol {
    public typealias InputActionType = LocationAction
    public typealias OutputActionType = LocationOutput
    public typealias StateType = LocationResources

    var locationManager: CLLocationManager!
    var geocoder: CLGeocoder!
    var searchCompleter: MKLocalSearchCompleter!

    private var getState: GetState<StateType>!
    private var output: AnyActionHandler<LocationOutput>!

    public func receiveContext(getState: @escaping GetState<LocationResources>, output: AnyActionHandler<LocationOutput>) {
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
        output.dispatch(.authorizationDidChange(locationManager.authorizationStatus))
    }

    public func handle(action: InputActionType, from dispatcher: ActionSource, state: @escaping GetState<StateType>) -> IO<OutputActionType> {
        return .init { [weak self] output in
            switch action {
            case .requestAuthorization:
                self?.locationManager.requestWhenInUseAuthorization()
            case let .requestReverseGeocoding(location):
                self?.geocoder.reverseGeocodeLocation(location) { placemarks, error in
                    if let placemarks = placemarks {
                        output.dispatch(.reverseGeocodingFinished(.success(placemarks)))
                    } else if let error = error {
                        output.dispatch(.reverseGeocodingFinished(.failure(error)))
                    }
                }
            case let .requestAutoCompletion(searchTerm):
                self?.searchCompleter.queryFragment = searchTerm
            case let .selectLocation(selection):
                switch selection {
                case .currentLocation:
                    if let currentLocation = self?.getState().currentLocation {
                        Self.persistLocation(currentLocation)
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
                        Self.persistLocation(location)
                    }
                    break
                }
            }
        }
    }

    static func persistLocation(_ location: CLLocation) {
        let encoder = JSONEncoder()
        let data = try! encoder.encode(LatLonAlt(location: location))
        UserDefaults.standard.set(data, forKey: "lastUsedLocation")
    }
}

extension LocationMiddleware: CLLocationManagerDelegate {
    public func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        output.dispatch(.authorizationDidChange(manager.authorizationStatus))
    }

    public func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let lastLocation = locations.last else {
            return
        }
        output.dispatch(.locationChanged(lastLocation))
    }
}

extension LocationMiddleware: MKLocalSearchCompleterDelegate {
    public func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        output.dispatch(.autocompletionFinished(.success(completer.results)))
    }

    public func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        output.dispatch(.autocompletionFinished(.failure(error)))
    }
}

fileprivate let logger = Logger(subsystem: "io.djben.location", category: "middleware")

extension EffectMiddleware where InputActionType == LocationOutput, OutputActionType == Never, StateType == Void, Dependencies == Void {
    public static var locationOutputLogger: EffectMiddleware<LocationOutput, Never, Void, Void> {
        EffectMiddleware<LocationOutput, Never, Void, Void>
            .onAction { action, _, getState in
                switch action {
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
                }
            return .doNothing
        }
    }
}

extension EffectMiddleware where InputActionType == LocationOutput, OutputActionType == LocationAction, StateType == LocationState, Dependencies == Void {
    /// This middleware triggers other `LocationAction`s from location output.
    public static var locationChainer: EffectMiddleware<LocationOutput, LocationAction, LocationState, Void> {
        EffectMiddleware.onAction { action, _, getState in
            switch action {
            case .locationChanged(let location):
                if getState().resources.selection == .currentLocation {
                    LocationMiddleware.persistLocation(location)
                }
                return .just(.requestReverseGeocoding(location))
            default:
                return .doNothing
            }
        }
    }
}

extension EffectMiddleware where InputActionType == LocationAction, OutputActionType == ElementsPropagatorAction, StateType == Void, Dependencies == Void {
    /// This middleware triggers other `ElementsPropagatorAction`s from location action.
    public static var locationToElementsPropagator: EffectMiddleware<LocationAction, ElementsPropagatorAction, Void, Void> {
        EffectMiddleware.onAction { action, _, getState in
            switch action {
            case .selectLocation(_):
                return .just(.purgePassesAndSnapshots)
            default:
                return .doNothing
            }
        }
    }
}
