//
//  LocationState.swift
//  SatelliteForecast
//
//  Created by Ben Lu on 6/4/21.
//

import Foundation
import CoreLocation
import MapKit

struct LocationState: Equatable {
    static func == (lhs: LocationState, rhs: LocationState) -> Bool {
        return lhs.authorizationStatus == rhs.authorizationStatus &&
        lhs.currentLocation == rhs.currentLocation &&
        lhs.currentLocationPlacemark == rhs.currentLocationPlacemark &&
        lhs.autocompletionResult?.successValue == rhs.autocompletionResult?.successValue &&
        lhs.selection == rhs.selection
    }

    var authorizationStatus: CLAuthorizationStatus
    /// The current user's location. Note that it may not be the actual location in use.
    var currentLocation: CLLocation?
    /// A reverse-geocoded placemark for the current location.
    var currentLocationPlacemark: CLPlacemark?
    /// The autocompletion result containing a list of autocompletion candidates.
    var autocompletionResult: Result<[MKLocalSearchCompletion], Error>?

    enum Selection: Equatable {
        case currentLocation
        case custom(MKLocalSearchCompletion, MKPlacemark)
    }

    /// The location selection. The user can either specifies current location, or a custom location from autocompletion search.
    var selection: Selection = .currentLocation

    /// The location in use. When the `selection` is `currentLocation`, it returns the current location (if available);
    /// when the `selection` is `custom`, it returns the custom location.
    var location: CLLocation? {
        switch selection {
        case .currentLocation:
            return currentLocation
        case .custom(_, let placemark):
            return CLLocation(
                latitude: placemark.coordinate.latitude,
                longitude: placemark.coordinate.longitude
            )
        }
    }

    /// The placemark in use. When the `selection` is `currentLocation`, it returns the current location's placemark (if available);
    /// when the `selection` is `custom`, it returns the custom location's placemark.
    var placemark: CLPlacemark? {
        switch selection {
        case .currentLocation:
            return currentLocationPlacemark
        case .custom(_, let placemark):
            return placemark
        }
    }

    static var empty: LocationState {
        LocationState(authorizationStatus: .notDetermined)
    }
}

extension CLLocationCoordinate2D: Equatable {
    public static func ==(lhs: CLLocationCoordinate2D, rhs: CLLocationCoordinate2D) -> Bool {
        return lhs.latitude == rhs.latitude && lhs.longitude == rhs.longitude
    }
}
