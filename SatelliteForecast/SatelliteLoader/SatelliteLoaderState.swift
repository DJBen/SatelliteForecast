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

struct SatelliteLoaderResources {
    var info: [SatelliteCategory: Loadable<Map<Int, SatelliteInfo>, SatelliteLoaderError>] = [:]

    subscript(noradIndex: Int) -> SatelliteInfo? {
        return info.values
            .first { $0.content?[noradIndex] != nil }
            .flatMap { $0.content?[noradIndex] }
    }
}

extension SatelliteLoaderResources: Equatable {}

struct SatelliteLoaderState {
    var resources: SatelliteLoaderResources = .init()
    var currentDate: Double = 0
}

extension SatelliteLoaderState: Equatable {}
