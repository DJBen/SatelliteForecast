//
//  SatelliteCategory+Impl.swift
//  SatelliteForecastImpl
//
//  Created by Ben Lu on 4/1/22.
//

import Foundation
import SatelliteForecast

extension SatelliteCategory {
    public var url: URL {
        switch self {
        case .brightest100:
            return URL(string: "https://www.celestrak.com/NORAD/elements/visual.txt")!
        case .last30DayLaunches:
            return URL(string: "https://celestrak.com/NORAD/elements/elements-new.txt")!
        case .active:
            return URL(string: "https://celestrak.com/NORAD/elements/active.txt")!
        }
    }

    public var localFilename: String {
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
