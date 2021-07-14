//
//  SatelliteLoaderState.swift
//  SatelliteForcast
//
//  Created by Ben Lu on 6/4/21.
//

import BTree
import Foundation
import SatelliteForcastCore
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
}

extension Map: Equatable where Key == Int, Value == SatelliteInfo {

}

struct SatelliteLoaderState: Equatable {
    static func == (lhs: SatelliteLoaderState, rhs: SatelliteLoaderState) -> Bool {
        return lhs.referenceDate == rhs.referenceDate
        && lhs.info == rhs.info
        && lhs.standaloneInfo == rhs.standaloneInfo
    }

    /// A date that mostly approximates the current date.
    var referenceDate: Double = Date().julianDate
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
