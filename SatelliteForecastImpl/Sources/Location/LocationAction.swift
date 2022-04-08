//
//  LocationAction.swift
//  SatelliteForecastImpl
//
//  Created by Ben Lu on 6/4/21.
//

import Foundation
import CoreLocation
import MapKit
import SatelliteForecast

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

public struct LocationState {
    public var resources: LocationResources
    /// A boolean indicating whether location settings is currently being showned by the view hierachy.
    public var showLocationSettings: Bool

    public init(resources: LocationResources, showLocationSettings: Bool) {
        self.resources = resources
        self.showLocationSettings = showLocationSettings
    }
}

