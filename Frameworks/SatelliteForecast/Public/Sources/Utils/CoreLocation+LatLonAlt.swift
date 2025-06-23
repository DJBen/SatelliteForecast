//
//  CoreLocation+LatLonAlt.swift
//  SatelliteForecast
//
//  Created by Ben Lu on 6/5/21.
//

import Foundation
import CoreLocation
@preconcurrency import SatelliteKit

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
extension CLLocationCoordinate2D: @retroactive Equatable {
    public static func ==(lhs: CLLocationCoordinate2D, rhs: CLLocationCoordinate2D) -> Bool {
        return lhs.latitude == rhs.latitude && lhs.longitude == rhs.longitude
    }

    public func close(to rhs: CLLocationCoordinate2D, tolerance: CGFloat) -> Bool {
        return abs(latitude - rhs.latitude) < tolerance && abs(longitude - rhs.longitude) < tolerance
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
