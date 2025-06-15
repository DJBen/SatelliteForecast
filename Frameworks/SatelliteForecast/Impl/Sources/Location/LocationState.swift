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
    public var navigationPath: NavigationPath
    public var fcmToken: String?

    public init(resources: LocationResources, navigationPath: NavigationPath, fcmToken: String?) {
        self.resources = resources
        self.navigationPath = navigationPath
        self.fcmToken = fcmToken
    }
}

