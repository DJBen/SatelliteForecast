//
//  LocationResources.swift
//  SatelliteForecast
//
//  Created by Ben Lu on 6/4/21.
//

import Foundation
import CoreLocation
import MapKit

public struct LocationResources: Equatable, @unchecked Sendable {
    public var authorizationStatus: CLAuthorizationStatus = .notDetermined
    /// The current user's location. Note that it may not be the actual location in use.
    public var currentLocation: CLLocation?
    /// A reverse-geocoded placemark for the current location.
    public var currentLocationPlacemark: CLPlacemark?
    /// The autocompletion result containing a list of autocompletion candidates.
    public var autocompletionResult: Result<[MKLocalSearchCompletion], Error>?

    public enum Selection: Equatable, @unchecked Sendable {
        case currentLocation
        case custom(MKLocalSearchCompletion, MKPlacemark)
    }

    /// The location selection. The user can either specifies current location, or a custom location from autocompletion search.
    public var selection: Selection = .currentLocation

    /// The location in use. When the `selection` is `currentLocation`, it returns the current location (if available);
    /// when the `selection` is `custom`, it returns the custom location.
    public var location: CLLocation? {
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
    public var placemark: CLPlacemark? {
        switch selection {
        case .currentLocation:
            return currentLocationPlacemark
        case .custom(_, let placemark):
            return placemark
        }
    }

    public init(
        authorizationStatus: CLAuthorizationStatus = .notDetermined,
        currentLocation: CLLocation? = nil,
        currentLocationPlacemark: CLPlacemark? = nil,
        autocompletionResult: Result<[MKLocalSearchCompletion], Error>? = nil,
        selection: LocationResources.Selection = .currentLocation
    ) {
        self.authorizationStatus = authorizationStatus
        self.currentLocation = currentLocation
        self.currentLocationPlacemark = currentLocationPlacemark
        self.autocompletionResult = autocompletionResult
        self.selection = selection
    }

    public static func == (lhs: LocationResources, rhs: LocationResources) -> Bool {
        return lhs.authorizationStatus == rhs.authorizationStatus &&
        lhs.currentLocation == rhs.currentLocation &&
        lhs.currentLocationPlacemark == rhs.currentLocationPlacemark &&
        lhs.autocompletionResult?.successValue == rhs.autocompletionResult?.successValue &&
        lhs.selection == rhs.selection
    }
}
