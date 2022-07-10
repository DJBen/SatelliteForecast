//
//  LocationState.swift
//  SatelliteForecastImpl
//
//  Created by Ben Lu on 6/4/21.
//

import SatelliteForecast

public struct LocationState {
    public var resources: LocationResources
    /// A boolean indicating whether location settings is currently being showned by the view hierachy.
    public var showLocationSettings: Bool

    public init(resources: LocationResources, showLocationSettings: Bool) {
        self.resources = resources
        self.showLocationSettings = showLocationSettings
    }
}

