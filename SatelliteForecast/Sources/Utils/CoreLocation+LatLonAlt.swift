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

extension LatLonAlt {
    public init(location: CLLocation) {
        self.init(
            lat: location.coordinate.latitude,
            lon: location.coordinate.longitude,
            alt: location.altitude
        )
    }
}
