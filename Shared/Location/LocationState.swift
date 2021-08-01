//
//  LocationState.swift
//  SatelliteForecast
//
//  Created by Ben Lu on 6/4/21.
//

import Foundation
import CoreLocation

struct LocationState: Equatable {
    var authorizationStatus: CLAuthorizationStatus
    /// The current user's location. Note that it may not be the actual location in use.
    var currentLocation: CLLocation?
    /// A reverse-geocoded placemark for the current location.
    var placemark: CLPlacemark?

    enum Selection: Equatable {
        case userLocation
        case custom(String, CLLocation)
    }

    var selection: Selection = .userLocation

    /// The location in use.
    var location: CLLocation? {
        switch selection {
        case .userLocation:
            return currentLocation
        case let .custom(_, customLocation):
            return customLocation
        }
    }

    static var empty: LocationState {
        LocationState(authorizationStatus: .notDetermined)
    }
}
