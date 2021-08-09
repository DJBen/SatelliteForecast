//
//  LocationAction.swift
//  SatelliteForecast
//
//  Created by Ben Lu on 6/4/21.
//

import Foundation
import CoreLocation
import MapKit

enum LocationAction {
    // Input
    case requestAuthorization
    case requestReverseGeocoding(CLLocation)
    case requestAutoCompletion(String)
    case selectLocation(LocationState.Selection)

    // Output
    case authorizationDidChange(CLAuthorizationStatus)
    case locationChanged(CLLocation)
    case reverseGeocodingFinished(Result<[CLPlacemark], Error>)
    case autocompletionFinished(Result<[MKLocalSearchCompletion], Error>)
}

extension LocationAction {
    public var authorization: CLAuthorizationStatus? {
        get {
            guard case let .authorizationDidChange(value) = self else { return nil }
            return value
        }
        set {
            guard case .authorizationDidChange = self, let newValue = newValue else { return }
            self = .authorizationDidChange(newValue)
        }
    }

    public var location: CLLocation? {
        get {
            guard case let .locationChanged(value) = self else { return nil }
            return value
        }
        set {
            guard case .locationChanged = self, let newValue = newValue else { return }
            self = .locationChanged(newValue)
        }
    }
}
