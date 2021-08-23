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
