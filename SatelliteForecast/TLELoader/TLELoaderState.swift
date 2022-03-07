//
//  TLELoaderState.swift
//  SatelliteForecast
//
//  Created by Ben Lu on 6/4/21.
//

import BTree
import Foundation
import SatelliteForecastCore
import SatelliteKit

struct TLELoaderResources {
    var info: [SatelliteCategory: Loadable<Map<Int, SatelliteInfo>, TLELoaderError>] = [:]

    subscript(noradIndex: Int) -> SatelliteInfo? {
        return info.values
            .first { $0.content?[noradIndex] != nil }
            .flatMap { $0.content?[noradIndex] }
    }
}

extension TLELoaderResources: Equatable {}

struct TLELoaderState {
    var resources: TLELoaderResources = .init()
    var currentDate: Double = 0
}

extension TLELoaderState: Equatable {}
