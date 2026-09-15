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
        let key: String
        switch self {
        case .iss: key = "25544"
        case .tianhe: key = "48274"
        case .brightest100: key = "visual"
        case .last30DayLaunches: key = "last-30-days"
        case .active: key = "active"
        }
        return URL(string: "https://us-central1-pass-prediction.cloudfunctions.net/orbital_data?category=\(key)")!
    }

    public var localFilename: String {
        switch self {
        case .iss:
            return "25544"
        case .tianhe:
            return "48274"
        case .brightest100:
            return "visual"
        case .last30DayLaunches:
            return "elements-new"
        case .active:
            return "active"
        }
    }
}
