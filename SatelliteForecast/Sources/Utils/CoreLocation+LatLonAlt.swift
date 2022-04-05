//
//  CoreLocation+LatLonAlt.swift
//  SatelliteForecast
//
//  Created by Ben Lu on 6/5/21.
//

import Foundation
import CoreLocation
import SatelliteKit

extension CLLocation {
    public convenience init(_ latLonAlt: LatLonAlt) {
        self.init(
            coordinate: CLLocationCoordinate2D(
                latitude: latLonAlt.lat,
                longitude: latLonAlt.lon
            ),
            altitude: latLonAlt.alt,
            horizontalAccuracy: 0,
            verticalAccuracy: 0,
            timestamp: Date()
        )
    }
}

extension CLLocationCoordinate2D {
    public init(_ latLonAlt: LatLonAlt) {
        self.init(
            latitude: latLonAlt.lat,
            longitude: limit180(latLonAlt.lon)
        )
    }
}

infix operator !~= : ComparisonPrecedence
extension CLLocationCoordinate2D: Equatable {
    public static func ==(lhs: CLLocationCoordinate2D, rhs: CLLocationCoordinate2D) -> Bool {
        return lhs.latitude == rhs.latitude && lhs.longitude == rhs.longitude
    }

    public static func ~=(lhs: CLLocationCoordinate2D, rhs: CLLocationCoordinate2D) -> Bool {
        return abs(lhs.latitude - rhs.latitude) < 1e-6 && abs(lhs.longitude - rhs.longitude) < 1e-6
    }

    public static func !~=(lhs: CLLocationCoordinate2D, rhs: CLLocationCoordinate2D) -> Bool {
        return !(lhs ~= rhs)
    }
}

extension LatLonAlt {
    public init(location: CLLocation) {
        self.init(
            lat: location.coordinate.latitude,
            lon: location.coordinate.longitude,
            alt: location.altitude
        )
    }
}
