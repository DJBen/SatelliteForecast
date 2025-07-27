//
//  LocationAction.swift
//  SatelliteForecast
//
//  Created by Ben Lu on 4/20/22.
//

import CoreLocation
import MapKit

public enum LocationAction {
    case requestAuthorization
    case requestReverseGeocoding(CLLocation)
    case requestAutoCompletion(String)
    case selectLocation(LocationResources.Selection)
}

extension LocationAction: Equatable {}

public enum LocationOutput {
    case authorizationDidChange(CLAuthorizationStatus)
    case locationChanged(CLLocation)
    case reverseGeocodingFinished(Result<[CLPlacemark], Error>)
    case autocompletionFinished(Result<[MKLocalSearchCompletion], Error>)
}

extension LocationOutput {
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
