//
//  SatelliteLoaderState.swift
//  SatelliteForcast
//
//  Created by Ben Lu on 6/4/21.
//

import Foundation
import SatelliteForcastCore
import SatelliteKit

enum SatelliteCategory: Equatable, Hashable {
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
}

struct SatelliteLoaderState: Equatable {
    /// A date that mostly approximates the current date.
    var referenceDate: Double = Date().julianDate
    var info: [SatelliteCategory: [SatelliteInfo]] = [:]
    var standaloneInfo: [SatelliteInfo] = []

    static var empty: SatelliteLoaderState {
        return SatelliteLoaderState()
    }

    func info(noradIndex: Int) -> SatelliteInfo? {
        return info.values.flatMap { $0 }
            .first { $0.noradIndex == noradIndex } ?? standaloneInfo.first { $0.noradIndex == noradIndex }
    }
}
