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

    var url: URL {
        switch self {
        case .brightest100:
            return URL(string: "https://www.celestrak.com/NORAD/elements/visual.txt")!
        case .last30DayLaunches:
            return URL(string: "https://celestrak.com/NORAD/elements/elements-new.txt")!
        case .active:
            return URL(string: "https://celestrak.com/NORAD/elements/active.txt")!
        }
    }

    var localFilename: String {
        switch self {
        case .brightest100:
            return "visual"
        case .last30DayLaunches:
            return "elements-new"
        case .active:
            return "active"
        }
    }
}
