//
//  CoreLocationState.swift
//  SatelliteForcast
//
//  Created by Ben Lu on 6/4/21.
//

import Foundation
import CoreLocation

struct CoreLocationState: Equatable {
    var authorizationStatus: CLAuthorizationStatus
    var location: CLLocation?

    static var empty: CoreLocationState {
        CoreLocationState(authorizationStatus: .notDetermined)
    }
}
