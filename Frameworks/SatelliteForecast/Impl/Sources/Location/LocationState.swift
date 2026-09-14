//
//  LocationState.swift
//  SatelliteForecastImpl
//
//  Created by Ben Lu on 6/4/21.
//

import SatelliteForecast
import SwiftUI

public struct LocationState {
    public var resources: LocationResources
    public var fcmToken: String?

    public init(resources: LocationResources, fcmToken: String?) {
        self.resources = resources
        self.fcmToken = fcmToken
    }
}

