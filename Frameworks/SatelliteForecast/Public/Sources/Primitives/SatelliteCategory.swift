//
//  SatelliteCategory.swift
//  SatelliteCategory
//
//  Created by Ben Lu on 8/22/21.
//

import Foundation

public enum SatelliteCategory: Equatable, Hashable, Codable {
    /// The brighest 100 (or so) satellites.
    case brightest100

    /// Satellites that are launched within last 30 days
    case last30DayLaunches

    /// All active satellites
    case active
}
