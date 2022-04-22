//
//  DateCoordinate.swift
//  SatelliteForecast
//
//  Created by Ben Lu on 4/3/22.
//

import SatelliteKit

public struct DateCoordinate {
    public let julianDate: Double
    public let coordinate: LatLonAlt

    public init(julianDate: Double, coordinate: LatLonAlt) {
        self.julianDate = julianDate
        self.coordinate = coordinate
    }
}

extension DateCoordinate: Equatable, Hashable {}
