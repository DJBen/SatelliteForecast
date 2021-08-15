//
//  SatelliteLoaderState.swift
//  SatelliteForecast
//
//  Created by Ben Lu on 6/4/21.
//

import BTree
import Foundation
import SatelliteForecastCore
import SatelliteKit

enum SatelliteCategory: Equatable, Hashable {
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
            return URL(string: "https://celestrak.com/NORAD/elements/tle-new.txt")!
        case .active:
            return URL(string: "https://celestrak.com/NORAD/elements/active.txt")!
        }
    }

    var localFilename: String {
        switch self {
        case .brightest100:
            return "visual"
        case .last30DayLaunches:
            return "tle-new"
        case .active:
            return "active"
        }
    }
}

struct SatelliteLoaderState: Equatable {
    /// A date that mostly approximates the current date.
    var currentDate: Double = Date().julianDate
    var info: [SatelliteCategory: Result<Map<Int, SatelliteInfo>, SatelliteLoaderError>] = [:]
    var standaloneInfo: Map<Int, SatelliteInfo> = [:]

    static var empty: SatelliteLoaderState {
        return SatelliteLoaderState()
    }

    subscript(noradIndex: Int) -> SatelliteInfo? {
        return info.values
            .first { $0.successValue?[noradIndex] != nil }
            .flatMap { $0.successValue?[noradIndex] } ?? standaloneInfo[noradIndex]
    }
}
