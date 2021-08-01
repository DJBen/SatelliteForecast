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
    var location: CLLocation?

    static var empty: LocationState {
        LocationState(authorizationStatus: .notDetermined)
    }
}
